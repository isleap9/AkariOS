using System.Text.RegularExpressions;
using AkariOS.Core.Apps;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;
using static AkariOS.Core.Data.PsSemantics;

namespace AkariOS.Core.Iso;

/// <summary>The image's side of the build (src/Core/Iso/Image.ps1 and Iso.ps1's registry part): its reads, its
/// registry, the removals, AkariOS copied in, the ADK.</summary>
public sealed partial class IsoBuild
{
    // ---- image reads (the page's lists too)

    /// <summary>The mounted image's provisioned apps without the frameworks (Get-AkariImageApps: removing them breaks
    /// the apps that use them).</summary>
    public IReadOnlyList<ImageApp> Apps(string mount) => [.. p.Image.ProvisionedApps(mount).Where(a => !Frameworks().IsMatch(a.Name))];

    [GeneratedRegex(@"DesktopAppInstaller|AppRuntime|VCLibs|UI\.Xaml|NET\.Native", RegexOptions.IgnoreCase)]
    private static partial Regex Frameworks();

    public IReadOnlyList<DismItem> Features(string mount) => p.Image.Features(mount);

    /// <summary>The installed capabilities (Get-AkariImageCapabilities).</summary>
    public IReadOnlyList<DismItem> Capabilities(string mount) => [.. p.Image.Capabilities(mount).Where(x => x.State == "Installed")];

    public IReadOnlyList<DismItem> Packages(string mount) => p.Image.Packages(mount);

    // ---- the ADK

    private const string AdkSetupUrl = "https://go.microsoft.com/fwlink/?linkid=2196127";

    private string? FindOscdimg() => new[] { "amd64", "x86" }
        .Select(a => Path.Combine(p.ProgramFilesX86, $@"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\{a}\Oscdimg\oscdimg.exe"))
        .FirstOrDefault(File.Exists);

    /// <summary>oscdimg.exe, the ADK's Deployment Tools installed first (quiet) when it is missing (Install-AkariAdk).</summary>
    public string Oscdimg()
    {
        if (FindOscdimg() is { } found) return found;
        Directory.CreateDirectory(p.Temp);
        var setup = Path.Combine(p.Temp, "akari-adksetup.exe");
        p.Http.Download(AdkSetupUrl, setup);
        try { p.Exe.Run(setup, "/quiet /norestart /features OptionId.DeploymentTools", wait: true, capture: false); }
        finally { TryDelete(setup); }
        return FindOscdimg() ?? throw new IsoException("The Windows ADK Deployment Tools did not install (oscdimg.exe is missing).");
    }

    // ---- the image's registry

    /// <summary>Loads the hives, writes the rows and deletes the wildcard keys, unloads them (Invoke-AkariIsoRegistry).</summary>
    private void WriteImageRegistry(string mount, IReadOnlyList<PsHashtable> rows, IReadOnlyList<string> keys)
    {
        var loaded = LoadHives(mount);
        try
        {
            WriteRegistry(rows, loaded);
            if (keys.Count > 0) RemoveKeys(keys, loaded);
        }
        finally { UnloadHives(loaded); }
    }

    private static bool Refused(Exception e) => e is UnauthorizedAccessException or System.Security.SecurityException or IOException;

    /// <summary>Data rows into the loaded hives (Write-AkariIsoRegistry): rows of a hive that isn't loaded are skipped;
    /// Trusted rows and rows an admin can't write go as TrustedInstaller, a key an admin can't delete too.</summary>
    private void WriteRegistry(IReadOnlyList<PsHashtable> rows, IReadOnlyList<string> loaded)
    {
        var trusted = new List<RegistryRow>();
        string? version = null;
        foreach (var r in IsoData.Rows(IsoData.Merge(rows), IsoData.HiveRoot))
        {
            if (!loaded.Contains(r.Hive, StringComparer.OrdinalIgnoreCase)) continue;
            var row = r.Row;
            // {DisplayVersion} = the image's own version (Disable version upgrades)
            if (row.Value is string v && v.Equals("{DisplayVersion}", StringComparison.OrdinalIgnoreCase))
            {
                version ??= p.Registry.GetValue($@"{IsoData.HiveRoot}SOFTWARE\Microsoft\Windows NT\CurrentVersion", "DisplayVersion") as string;
                if (string.IsNullOrEmpty(version)) { version = null; p.Log.Write($"The image has no DisplayVersion: {row.Name} left out"); continue; }
                row = row with { Value = version };
            }
            if (r.Trusted) { trusted.Add(row); continue; }
            try { p.Registry.Invoke([row], TweakMode.Apply, 0); }
            catch (Exception e) when (Refused(e))
            {
                if (!row.IsKeyRow) trusted.Add(row);
                else if (row.Value is null) TrustedKey(row.Path);
                else p.Log.Write($"Could not change {row.Path}: {e.Message}");
            }
        }
        if (trusted.Count > 0) p.Registry.Invoke(trusted, TweakMode.Apply, 0, asTrusted: true);
    }

    /// <summary>A key deleted with its contents as TrustedInstaller (Defender's services, for one).</summary>
    private void TrustedKey(string path) => p.Trusted.Run(() => p.Registry.DeleteKey(path));

    /// <summary>Deletes the keys whose last part matches ('SOFTWARE\...\Name*') in the loaded hives; one an admin can't
    /// delete goes as TrustedInstaller (Remove-AkariIsoKeys).</summary>
    private void RemoveKeys(IReadOnlyList<string> patterns, IReadOnlyList<string> loaded)
    {
        foreach (var pattern in patterns)
        {
            var cut = pattern.IndexOf('\\');
            if (cut < 0) continue;
            var hive = pattern[..cut];
            if (!loaded.Contains(hive, StringComparer.OrdinalIgnoreCase)) continue;
            var rest = pattern[(cut + 1)..];
            var parent = $@"{IsoData.HiveRoot}{hive}\{Path.GetDirectoryName(rest)}".TrimEnd('\\');
            var leaf = Path.GetFileName(rest);
            foreach (var sub in p.Registry.SubKeys(parent).Where(k => Like(k, leaf)).ToList())
            {
                var key = $@"{parent}\{sub}";
                try { p.Registry.DeleteKey(key); }
                catch (Exception e) when (Refused(e)) { TrustedKey(key); }
            }
        }
    }

    // ---- removals

    private const string Store = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore";

    /// <summary>Provisioned apps out of the image (Remove-AkariImageApps, zISO's Remove-Packages): deprovisioned in its
    /// registry so Windows doesn't bring them back, removed with DISM, their folders deleted.</summary>
    private void RemoveApps(string mount, IReadOnlyList<string> packages)
    {
        var loaded = LoadHives(mount);
        try
        {
            foreach (var pkg in packages)
            {
                var name = pkg.Split('_')[0];
                WriteRegistry([PsHashtable.Of(("Path", $@"{Store}\Deprovisioned\{IsoData.Family(pkg)}"), ("Value", "Key"))], loaded);
                RemoveKeys([$@"{Store}\InboxApplications\{name}_*", $@"{Store}\Applications\{name}_*", $@"{Store}\Staged\{name}_*"], loaded);
            }
        }
        finally { UnloadHives(loaded); }
        foreach (var pkg in packages)
        {
            var name = pkg.Split('_')[0];
            p.Log.Write($"Removing {name}");
            p.Image.Dism([$"/Image:{mount}", "/Set-NonRemovableAppPolicy", $"/PackageFamily:{IsoData.Family(pkg)}", "/NonRemovable:0"]);
            var code = p.Image.Dism([$"/Image:{mount}", "/Remove-ProvisionedAppxPackage", $"/PackageName:{pkg}"]);
            if (code != 0) p.Log.Write($"  DISM could not remove it (exit code {code})");
            RemovePaths(mount, [$@"Program Files\WindowsApps\{name}_*", $@"Windows\SystemApps\{name}_*"]);
        }
    }

    /// <summary>Features, capabilities, OS packages: one call each; a failure is logged and the build goes on (as
    /// zISO; Remove-AkariImageItems).</summary>
    private void RemoveItems(string mount, string kind, IReadOnlyList<string> names)
    {
        foreach (var n in names)
        {
            p.Log.Write($"Removing {kind.ToLowerInvariant()} {n}");
            var code = p.Image.Remove(mount, kind, n);
            if (code != 0 && code != 3010) p.Log.Write($"  DISM could not remove it (exit code {code})");
        }
    }

    /// <summary>Paths under the mounted image (the last part may hold wildcards) removed, ownership taken first
    /// (Remove-AkariImagePaths): how many went.</summary>
    private int RemovePaths(string mount, IEnumerable<string> paths)
    {
        var n = 0;
        foreach (var item in paths.SelectMany(x => Match(Path.Combine(mount, x))))
        {
            Own(item);
            n += Machine.SystemPaths.Remove([item]);
        }
        return n;
    }

    // Get-Item -Path <p> -Force: the item, or every item its last part's wildcards match
    private static IEnumerable<string> Match(string path)
    {
        var name = Path.GetFileName(path);
        if (name.IndexOfAny(['*', '?']) < 0) return Exists(path) ? [path] : [];
        var folder = Path.GetDirectoryName(path);
        if (folder is null || !Directory.Exists(folder)) return [];
        return [.. Directory.EnumerateFileSystemEntries(folder, name).Order(StringComparer.OrdinalIgnoreCase)];
    }

    /// <summary>takeown + icacls for the Administrators group, everything inside too (Grant-AkariOwnership).</summary>
    private void Own(string path)
    {
        if (!Exists(path)) return;
        var system32 = Path.Combine(p.Windows, "System32");
        p.Exe.Run(Path.Combine(system32, "takeown.exe"), $"/f \"{path}\" /a /r /d y");
        p.Exe.Run(Path.Combine(system32, "icacls.exe"), $"\"{path}\" /grant *S-1-5-32-544:F /t /q");
    }

    // ---- AkariOS in the image

    /// <summary>The image's C:\AkariOS: the running exe as AkariOS-Native.exe, a Start menu and a desktop shortcut for
    /// every user (the port's Copy-AkariToImage, with the native exe in place of the folder).</summary>
    private void CopyAkariOS(string mount, string exe)
    {
        var dest = Path.Combine(mount, "AkariOS");
        if (Directory.Exists(dest)) DeleteTree(dest);
        Directory.CreateDirectory(dest);
        File.Copy(exe, Path.Combine(dest, InImageExe), overwrite: true);
        foreach (var lnk in new[] { @"ProgramData\Microsoft\Windows\Start Menu\Programs\AkariOS.lnk", @"Users\Public\Desktop\AkariOS.lnk" })
        {
            var file = Path.Combine(mount, lnk);
            Directory.CreateDirectory(Path.GetDirectoryName(file)!);
            p.Shortcuts.Create(file, $@"C:\AkariOS\{InImageExe}", @"C:\AkariOS");
        }
    }

    /// <summary>The exe's name in the image.</summary>
    public const string InImageExe = "AkariOS-Native.exe";
}
