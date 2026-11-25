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

    /// <summary>The image's own app logos (name → a copy in <paramref name="folder"/>): each app's AppxManifest.xml
    /// under the mount's WindowsApps read as for installed apps (<see cref="AppPackages.Logos"/>), the logo copied out,
    /// as the image is unmounted after a build. An app with no readable logo is left out.</summary>
    public IReadOnlyDictionary<string, string> AppLogos(string mount, IEnumerable<ImageApp> apps, string folder)
    {
        var found = AppPackages.Logos(apps.Select(a => new AppPackage(a.Name, a.Package, "",
            Path.Combine(mount, "Program Files", "WindowsApps", a.Package), false, false, false, false)));
        var copies = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var (name, file) in found)
        {
            try
            {
                Directory.CreateDirectory(folder);
                var copy = Path.Combine(folder, name + Path.GetExtension(file));
                File.Copy(file, copy, overwrite: true);
                copies[name] = copy;
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        }
        return copies;
    }

    [GeneratedRegex(@"DesktopAppInstaller|AppRuntime|VCLibs|UI\.Xaml|NET\.Native", RegexOptions.IgnoreCase)]
    private static partial Regex Frameworks();

    public IReadOnlyList<DismItem> Features(string mount) => p.Image.Features(mount);

    /// <summary>The installed capabilities (Get-AkariImageCapabilities).</summary>
    public IReadOnlyList<DismItem> Capabilities(string mount) => [.. p.Image.Capabilities(mount).Where(x => x.State == "Installed")];

    public IReadOnlyList<DismItem> Packages(string mount) => p.Image.Packages(mount);

    /// <summary>The page's three lists in one read: the features as they are, the installed capabilities, the packages.</summary>
    public ImageItems Items(string mount)
    {
        var all = p.Image.Items(mount);
        return all with { Capabilities = [.. all.Capabilities.Where(x => x.State == "Installed")] };
    }

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
        // DISM first: it finds an offline image's provisioned apps through AppxAllUserStore's keys, so deleting them
        // before made every removal fail with exit code 2 (not found)
        foreach (var pkg in packages)
        {
            var name = pkg.Split('_')[0];
            Op($"App {name}", () =>
            {
                p.Log.Write($"Removing {name}");
                p.Image.Dism([$"/Image:{mount}", "/Set-NonRemovableAppPolicy", $"/PackageFamily:{IsoData.Family(pkg)}", "/NonRemovable:0"]);
                var code = p.Image.Dism([$"/Image:{mount}", "/Remove-ProvisionedAppxPackage", $"/PackageName:{pkg}"]);
                if (code != 0) p.Log.Write($"  DISM could not remove it (exit code {code})");
                RemovePaths(mount, [$@"Program Files\WindowsApps\{name}_*", $@"Windows\SystemApps\{name}_*"]);
                return code == 0 ? (IsoOpState.Done, "") : (IsoOpState.Failed, $"DISM exit code {code}; its files removed");
            });
        }
        // then each app marked deprovisioned (a feature update doesn't bring it back) and its keys DISM left removed
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
    }

    /// <summary>Features, capabilities, OS packages: one call each; a failure is logged and the build goes on (as
    /// zISO; Remove-AkariImageItems).</summary>
    private void RemoveItems(string mount, string kind, IReadOnlyList<string> names)
    {
        foreach (var n in names)
        {
            Op($"{KindName(kind)} {n}", () =>
            {
                p.Log.Write($"Removing {kind.ToLowerInvariant()} {n}");
                var code = p.Image.Remove(mount, kind, n);
                if (code != 0 && code != 3010) p.Log.Write($"  DISM could not remove it (exit code {code})");
                return code switch
                {
                    0 => (IsoOpState.Done, ""),
                    3010 => (IsoOpState.Done, "Finishes when the new Windows first starts"),
                    _ => (IsoOpState.Failed, $"DISM exit code {code}"),
                };
            });
        }
    }

    /// <summary>The picked names and the groups' own, once each, in that order.</summary>
    private static IReadOnlyList<string> Names(IEnumerable<string> picked, IEnumerable<string> fromGroups) =>
        [.. picked.Concat(fromGroups).Distinct(StringComparer.OrdinalIgnoreCase)];

    // ---- the AkariOS mode: the preset's settings in the image, the rest at the first sign-in

    /// <summary>
    /// The baked Tweaks (<see cref="IsoChoices.Bake"/>) written into the loaded hives, one operation each (a row an
    /// admin can't write goes as TrustedInstaller; a Tweak whose hive the image lacks is skipped), then the Default
    /// user's RunOnce entry that runs the rest of the preset at each new account's first sign-in.
    /// </summary>
    private void BakeAkariOS(string mount, IsoChoices c)
    {
        var loaded = LoadHives(mount);
        try
        {
            var build = c.ImageBuild > 0 ? c.ImageBuild : 22000;
            foreach (var item in c.Bake ?? [])
                Op($"Tweak {item.Tweak.Name}", () => BakeOne(item, build, loaded));
            if (c.FirstSignIn && !string.IsNullOrEmpty(c.AkariExe))
                Op("The rest of AkariOS at the first sign-in", () =>
                {
                    if (!loaded.Contains("NTUSER", StringComparer.OrdinalIgnoreCase)) return (IsoOpState.Skipped, "The image has no Default user hive");
                    p.Registry.SetValue(IsoData.HiveRoot + IsoWizard.RunOnceKey, IsoWizard.RunOnceName, IsoWizard.FirstSignInCommand, "String");
                    return (IsoOpState.Done, "A RunOnce entry for each new account: one UAC prompt, then One-click's console");
                });
        }
        finally { UnloadHives(loaded); }
    }

    private (IsoOpState, string) BakeOne(IsoBakeItem item, int build, IReadOnlyList<string> loaded)
    {
        var t = item.Tweak;
        var rows = t.Registry!.Select(r => r with { Path = IsoWizard.ImagePath(r.Path)! }).ToList();
        // a hive the image doesn't have: nothing written (it would land in the real HKLM)
        if (rows.Select(r => HiveOf(r.Path)).FirstOrDefault(h => !loaded.Contains(h, StringComparer.OrdinalIgnoreCase)) is { } missing)
            return (IsoOpState.Skipped, $"The image has no {missing} hive");
        if (t.Kind == TweakKind.Choice)
        {
            var row = rows[0];
            try { p.Registry.SetValue(row.Path, row.Name!, item.Value!, row.Type ?? "DWord"); }
            catch (Exception e) when (Refused(e)) { p.Trusted.Run(() => p.Registry.SetValue(row.Path, row.Name!, item.Value!, row.Type ?? "DWord")); }
            return (IsoOpState.Done, $"{item.Value}");
        }
        try { p.Registry.Invoke(rows, TweakMode.Apply, build); }
        catch (Exception e) when (Refused(e)) { p.Registry.Invoke(rows, TweakMode.Apply, build, asTrusted: true); }
        return (IsoOpState.Done, "");
    }

    /// <summary>
    /// Tiny11 Core's pruning (ADR 0010): every WinSxS folder but the store's metadata and the runtimes Windows loads
    /// from it removed, ownership taken once for the store. Refused (the build fails, nothing removed) while servicing
    /// is pending or when the image's own runtimes can't be found.
    /// </summary>
    private void PruneComponentStore(string mount)
    {
        if (File.Exists(Path.Combine(mount, IsoPlan.PendingXml)))
            throw new IsoException("The image has pending servicing (pending.xml): Minimal can't prune its component store. Nothing was pruned.");
        var store = Path.Combine(mount, @"Windows\WinSxS");
        if (!Directory.Exists(store)) throw new IsoException("The image has no Windows\\WinSxS folder: nothing to prune.");
        var folders = Directory.EnumerateDirectories(store).Select(Path.GetFileName).OfType<string>().ToList();
        foreach (var family in IsoWizard.RequiredRuntimes)
            if (!folders.Any(f => f.Contains(family, StringComparison.OrdinalIgnoreCase) && IsoWizard.KeepInComponentStore(f)))
                throw new IsoException($"Minimal can't find the image's {family} runtime in WinSxS: nothing was pruned.");
        var removable = folders.Where(f => !IsoWizard.KeepInComponentStore(f)).ToList();
        Op($"{removable.Count} component folders", () =>
        {
            Own(store);
            var n = removable.Sum(f => Machine.SystemPaths.Remove([Path.Combine(store, f)]));
            p.Log.Write($"Pruned {n} of {removable.Count} component folders");
            return (IsoOpState.Done, $"{n} removed; {folders.Count - removable.Count} kept");
        });
    }

    // HKLM:\AkariIso_SOFTWARE\... → SOFTWARE
    private static string HiveOf(string path)
    {
        var rest = path[IsoData.HiveRoot.Length..];
        var cut = rest.IndexOf('\\');
        return cut < 0 ? rest : rest[..cut];
    }

    /// <summary>Turbo: the Windows features out in one dism /Disable-Feature with a /FeatureName each (payload
    /// removed), then each one's state read back: Done when it is disabled or gone, Failed when it isn't.</summary>
    private void RemoveFeaturesAtOnce(string mount, IReadOnlyList<string> names)
    {
        if (names.Count == 0) return;
        var clock = System.Diagnostics.Stopwatch.StartNew();
        foreach (var n in names) _ops?.Report(new IsoOperation(_stage, $"{KindName("Feature")} {n}", IsoOpState.Running, TimeSpan.Zero));
        p.Log.Write($"Removing {names.Count} Windows features at once");
        var code = p.Image.Dism([$"/Image:{mount}", "/Disable-Feature", .. names.Select(n => $"/FeatureName:{n}"), "/Remove", "/NoRestart"]);
        if (code != 0 && code != 3010) p.Log.Write($"  DISM exit code {code}: each feature's state read back");
        var states = p.Image.Features(mount).ToDictionary(f => f.Name, f => f.State, StringComparer.OrdinalIgnoreCase);
        var each = TimeSpan.FromTicks(clock.Elapsed.Ticks / names.Count);
        foreach (var n in names)
        {
            var (state, note) = !states.TryGetValue(n, out var now) ? (IsoOpState.Done, "Not in the image any more")
                : now.Contains("Disabled", StringComparison.OrdinalIgnoreCase) ? (IsoOpState.Done, code == 3010 ? "Finishes when the new Windows first starts" : "")
                : (IsoOpState.Failed, $"Still {now} (DISM exit code {code})");
            if (state == IsoOpState.Failed) p.Log.Write($"  {n} is still {now}");
            Ended($"{KindName("Feature")} {n}", state, each, note);
        }
    }

    /// <summary>Remove leftover image data: <see cref="IsoPlan.Leftovers"/>, one operation each; all kept while the
    /// image has pending servicing.</summary>
    private void RemoveLeftovers(string mount)
    {
        if (File.Exists(Path.Combine(mount, IsoPlan.PendingXml)))
        {
            p.Log.Write("The image has pending servicing (pending.xml): leftover data kept");
            Op("Leftover image data", () => (IsoOpState.Skipped, "The image has pending servicing (pending.xml): kept"));
            return;
        }
        foreach (var path in IsoPlan.Leftovers)
            Op(path, () => RemovePaths(mount, [path]) is var n and > 0 ? (IsoOpState.Done, $"{n} removed") : (IsoOpState.Skipped, "Nothing there"));
    }

    private static string KindName(string kind) => kind switch
    {
        "Feature" => "Windows feature",
        "Capability" => "Optional feature",
        "Package" => "OS package",
        _ => kind,
    };
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
