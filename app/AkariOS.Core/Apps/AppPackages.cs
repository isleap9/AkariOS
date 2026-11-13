using System.Xml.Linq;
using AkariOS.Core.Data;

namespace AkariOS.Core.Apps;

/// <summary>An installed Store package, for one user (Get-AppxPackage -AllUsers lists one per user). System = signed
/// by Windows (SignatureKind System).</summary>
public sealed record AppPackage(string Name, string FullName, string FamilyName, string? InstallLocation,
    bool IsFramework, bool IsResource, bool NonRemovable, bool IsSystem);

/// <summary>Windows' package manager (Windows.Management.Deployment.PackageManager): every user's packages, removal
/// for all users, registrations and adds. Throws when Windows refuses.</summary>
public interface IPackageManager
{
    IReadOnlyList<AppPackage> AllUsers();

    /// <summary>Removes the package for every user (Remove-AppxPackage -AllUsers).</summary>
    void Remove(string fullName);

    /// <summary>Registers a package already on the PC for this user (Add-AppxPackage -RegisterByFamilyName).</summary>
    void RegisterByFamily(string family);

    /// <summary>Registers a package from its AppxManifest.xml (Add-AppxPackage -DisableDevelopmentMode -Register).</summary>
    void Register(string manifest);

    /// <summary>Adds a package file (.appx, .msix, .msixbundle).</summary>
    void Add(string file);

    /// <summary>The provisioned apps (Get-AppxProvisionedPackage: every new user gets them).</summary>
    IReadOnlyList<ProvisionedApp> ProvisionedApps();

    /// <summary>Removes a provisioned app (Remove-AppxProvisionedPackage), by its family name.</summary>
    void Deprovision(string family);
}

/// <summary>A provisioned app: its package name (Get-AppxProvisionedPackage's DisplayName) and family.</summary>
public sealed record ProvisionedApp(string DisplayName, string Family);

/// <summary>A capability or feature and its state as the DISM cmdlets name it (Installed / NotPresent…, Enabled /
/// Disabled…).</summary>
public sealed record DismItem(string Name, string State);

/// <summary>A driver package as Get-WindowsDriver names it: Driver = its oemNN.inf, OriginalFileName (the .inf's path in
/// the driver store), ProviderName, ClassName, Version ("31.0.15.5222"), Date.</summary>
public sealed record DriverPackage(string Driver, string OriginalFileName, string ProviderName, string ClassName, string Version, DateTime Date);

/// <summary>DISM on the running Windows (dismapi.dll): Optional features (capabilities) and Windows features. Throws
/// when DISM refuses.</summary>
public interface IDism
{
    IReadOnlyList<DismItem> Capabilities();
    IReadOnlyList<DismItem> Features();

    /// <summary>One capability's state; null when Windows has no such capability.</summary>
    string? CapabilityState(string name);

    string? FeatureState(string name);
    void RemoveCapability(string name);

    /// <summary>Turns it off without restarting (the Run says a restart is due).</summary>
    void DisableFeature(string name);

    /// <summary>The third-party driver packages in the driver store (Get-AkariDriverPackages = Get-WindowsDriver
    /// -Online). Read only.</summary>
    IReadOnlyList<DriverPackage> Drivers() => throw new NotSupportedException("this engine can't read the driver store");

    /// <summary>Enable-AkariFeature: turns it on with the features it needs, no restart; <paramref name="source"/> (a
    /// Windows setup's sources\sxs) = its files from there only, else from Windows Update.</summary>
    void EnableFeature(string name, string? source) => throw new NotSupportedException("this engine can't turn Windows features on");

    /// <summary>Add-AkariCapability: its files come from Windows Update.</summary>
    void AddCapability(string name) => throw new NotSupportedException("this engine can't add capabilities");
}

/// <summary>
/// The engine side of the Remove tab (src/Core/Appx.ps1): Store apps (AppxRemove), Optional features
/// (CapabilityRemove), Windows features (FeatureDisable). No Tweak logic: the Groups' Entries and the legacy removals
/// call it.
/// </summary>
public sealed class AppPackages(IPackageManager packages, IDism dism, IAkariLog log)
{
    /// <summary>$AkariAppxNever: never listed, never removed (Explorer, the taskbar, Start or Settings break).</summary>
    public static IReadOnlyList<string> Never { get; } = ["*CBS*", "Microsoft.Windows.ShellExperienceHost", "Microsoft.Windows.StartMenuExperienceHost", "windows.immersivecontrolpanel"];

    /// <summary>Get-AppxPackage's NonRemovable has no WinRT property: the native app reads it as System-signed, plus
    /// the two Store-signed packages Windows also refuses to remove (checked on Windows 11 26100).</summary>
    public static IReadOnlyList<string> NonRemovableStore { get; } = ["Microsoft.DesktopAppInstaller", "Microsoft.SecHealthUI"];

    public static bool IsNever(string name) => Never.Any(p => PsSemantics.Like(name, p));

    public IReadOnlyList<AppPackage> All() => packages.AllUsers();

    /// <summary>Get-AkariAppxInstalled: the removable packages' names, sorted, once each.</summary>
    public IReadOnlyList<string> Installed(IReadOnlyList<AppPackage>? list = null) =>
        (list ?? packages.AllUsers())
            .Where(p => !p.IsFramework && !p.IsResource && !p.NonRemovable && !p.IsSystem && !IsNever(p.Name))
            .Select(p => p.Name).Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.InvariantCultureIgnoreCase).ToList();

    public bool IsInstalled(string name) => packages.AllUsers().Any(p => string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase));

    /// <summary>Remove-AkariAppx: for every user, then its provisioned copy (so a new user doesn't get it back; a
    /// copy DISM won't remove is only logged).</summary>
    public void Remove(string name)
    {
        if (IsNever(name)) throw new InvalidOperationException($"{name} is needed by Windows and is never removed");
        foreach (var p in packages.AllUsers().Where(p => string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase)))
            packages.Remove(p.FullName);
        try
        {
            foreach (var p in packages.ProvisionedApps().Where(p => string.Equals(p.DisplayName, name, StringComparison.OrdinalIgnoreCase)))
                packages.Deprovision(p.Family);
        }
        catch (Exception e) { log.Write($"{name}: its provisioned copy stays ({e.Message})"); }
    }

    public IReadOnlyList<string> InstalledCapabilities() => Names(dism.Capabilities(), "Installed");
    public IReadOnlyList<string> EnabledFeatures() => Names(dism.Features(), "Enabled");
    public bool CapabilityInstalled(string name) => string.Equals(dism.CapabilityState(name), "Installed", StringComparison.OrdinalIgnoreCase);
    public bool FeatureEnabled(string name) => string.Equals(dism.FeatureState(name), "Enabled", StringComparison.OrdinalIgnoreCase);
    /// <summary>Add-AppxPackage: a package file installed for the user (the NVIDIA Control Panel).</summary>
    public void Add(string file) => packages.Add(file);

    public void RemoveCapability(string name) => dism.RemoveCapability(name);
    public void DisableFeature(string name) => dism.DisableFeature(name);

    /// <summary>Get-AkariFeatureState / Get-AkariCapabilityState: the state as DISM names it, null when this Windows
    /// has none.</summary>
    public string? FeatureState(string name) => dism.FeatureState(name);
    public string? CapabilityState(string name) => dism.CapabilityState(name);
    public void EnableFeature(string name, string? source) => dism.EnableFeature(name, source);
    public void AddCapability(string name) => dism.AddCapability(name);

    /// <summary>Find-AkariWindowsSource: the first &lt;root&gt;\sources\sxs (a mounted Windows ISO or a setup USB stick),
    /// null when none has one.</summary>
    public static string? WindowsSource(IEnumerable<string> roots) =>
        roots.Select(r => Path.Combine(r, "sources", "sxs")).FirstOrDefault(Directory.Exists);

    private static List<string> Names(IEnumerable<DismItem> items, string state) =>
        items.Where(i => string.Equals(i.State, state, StringComparison.OrdinalIgnoreCase))
            .Select(i => i.Name).Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.InvariantCultureIgnoreCase).ToList();

    private static readonly string[] LogoSizes = ["targetsize-48_altform-unplated", "targetsize-32_altform-unplated", "targetsize-48", "targetsize-32", "scale-200", "scale-100"];

    /// <summary>Get-AkariAppxLogos: package name → its app list logo file (the first app's Square44x44Logo, else the
    /// package Logo; an unplated 48 / 32 px file first). Packages with no readable logo are left out; never throws.</summary>
    public static Dictionary<string, string> Logos(IEnumerable<AppPackage> list)
    {
        var logos = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var p in list)
        {
            try
            {
                if (string.IsNullOrEmpty(p.InstallLocation) || logos.ContainsKey(p.Name)) continue;
                var m = XDocument.Load(Path.Combine(p.InstallLocation, "AppxManifest.xml")).Root!;
                IEnumerable<XElement> Kids(IEnumerable<XElement> e, string n) => e.Elements().Where(x => x.Name.LocalName == n);
                var bases = Kids(Kids(Kids([m], "Applications"), "Application"), "VisualElements")
                    .Select(v => (string?)v.Attribute("Square44x44Logo") ?? v.Elements().FirstOrDefault(x => x.Name.LocalName == "Square44x44Logo")?.Value)
                    .Concat(Kids(Kids([m], "Properties"), "Logo").Select(l => l.Value))
                    .Where(b => !string.IsNullOrEmpty(b));
                foreach (var b in bases)
                {
                    var file = Path.Combine(p.InstallLocation, b!);
                    var dir = Path.GetDirectoryName(file)!;
                    if (!Directory.Exists(dir)) continue;
                    var stem = Path.GetFileNameWithoutExtension(file);
                    var found = LogoSizes.Select(q => Path.Combine(dir, $"{stem}.{q}.png")).FirstOrDefault(File.Exists);
                    if (found is null && File.Exists(file)) found = file;
                    found ??= Directory.GetFiles(dir, $"{stem}.*.png").FirstOrDefault();
                    if (found is not null) { logos[p.Name] = found; break; }
                }
            }
            catch (Exception) { }
        }
        return logos;
    }
}
