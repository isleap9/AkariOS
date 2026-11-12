using Windows.Foundation;
using Windows.Management.Deployment;

namespace AkariOS.Core.Apps;

/// <summary>The real package manager (Windows.Management.Deployment.PackageManager; guarded). Every user's packages
/// need an elevated process, as Get-AppxPackage -AllUsers does.</summary>
public sealed class WindowsPackages : IPackageManager
{
    private readonly PackageManager _pm;

    public WindowsPackages()
    {
        SystemGuard.Check("Store packages");
        _pm = new PackageManager();
    }

    public IReadOnlyList<AppPackage> AllUsers()
    {
        var list = new List<AppPackage>();
        foreach (var p in _pm.FindPackages())
        {
            string? location;
            try { location = p.InstalledPath; } catch (Exception) { location = null; }
            var name = p.Id.Name;
            list.Add(new AppPackage(name, p.Id.FullName, p.Id.FamilyName, location, p.IsFramework, p.IsResourcePackage,
                AppPackages.NonRemovableStore.Contains(name, StringComparer.OrdinalIgnoreCase), p.SignatureKind == Windows.ApplicationModel.PackageSignatureKind.System));
        }
        return list;
    }

    public void Remove(string fullName) => Wait(_pm.RemovePackageAsync(fullName, RemovalOptions.RemoveForAllUsers));

    public void RegisterByFamily(string family) => Wait(_pm.RegisterPackageByFamilyNameAsync(family, null, DeploymentOptions.None, null, null));

    public void Register(string manifest) => Wait(_pm.RegisterPackageAsync(new Uri(manifest), null, DeploymentOptions.None));

    public void Add(string file) => Wait(_pm.AddPackageAsync(new Uri(file), null, DeploymentOptions.None));

    public IReadOnlyList<ProvisionedApp> ProvisionedApps() =>
        _pm.FindProvisionedPackages().Select(p => new ProvisionedApp(p.Id.Name, p.Id.FamilyName)).ToList();

    public void Deprovision(string family) => Wait(_pm.DeprovisionPackageForAllUsersAsync(family));

    /// <summary>Waits for the operation; Windows' error text when it fails.</summary>
    private static void Wait(IAsyncOperationWithProgress<DeploymentResult, DeploymentProgress> op)
    {
        DeploymentResult r;
        try { r = op.AsTask().GetAwaiter().GetResult(); }
        catch (Exception e) { throw new InvalidOperationException($"0x{e.HResult:X8}: {e.Message}".Trim(), e); }
        if (r.ExtendedErrorCode is { HResult: not 0 } x)
            throw new InvalidOperationException($"0x{x.HResult:X8}: {(string.IsNullOrWhiteSpace(r.ErrorText) ? x.Message : r.ErrorText)}".Trim());
    }
}
