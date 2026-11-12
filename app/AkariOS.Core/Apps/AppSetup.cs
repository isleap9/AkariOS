using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Apps;

/// <summary>An installed program's uninstall entry: its display name and key name (an MSI's product code).</summary>
public sealed record MsiProduct(string Name, string Code);

/// <summary>Helpers for app removals and installs (src/Core/AppSetup.ps1), no app logic. Programs run through the
/// engine's <see cref="IExe"/>, processes through <see cref="IProcesses"/>.</summary>
public static class AppSetup
{
    /// <summary>The uninstall keys, both registry views.</summary>
    public static IReadOnlyList<string> UninstallRoots { get; } =
        [@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"];

    private static string System32(TweakContext c) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32");

    private static IExe Exe(TweakContext c) => TweakServices.Need(c.Services.Exe, "program runner");

    /// <summary>The autostart keys Remove-AkariStartup clears: the real user's, the machine's 64- and 32-bit ones.</summary>
    public static IReadOnlyList<string> RunKeys { get; } =
    [
        @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    ];

    /// <summary>Remove-AkariStartup: the autostart values whose name is like one of the patterns.</summary>
    public static void RemoveStartup(TweakContext c, params string[] names) => RemoveStartup(c, names, RunKeys);

    /// <summary>Remove-AkariStartup with its own keys (a RunOnce).</summary>
    public static void RemoveStartup(TweakContext c, IReadOnlyList<string> names, IReadOnlyList<string> keys)
    {
        foreach (var key in keys)
            foreach (var v in c.Registry.ValueNames(key))
                if (names.Any(n => PsSemantics.Like(v, n))) c.Registry.RemoveValue(key, v);
    }

    private const string ActiveSetup = @"HKLM:\Software\Microsoft\Active Setup\Installed Components";

    /// <summary>Remove-AkariUpdaters: an app's background updaters: the services and scheduled tasks named like
    /// *name* (services stopped, then deleted), and the Active Setup entries whose title is like *activeSetup*.</summary>
    public static void RemoveUpdaters(TweakContext c, string name, string? activeSetup = null)
    {
        var like = $"*{name}*";
        var services = TweakServices.Need(c.Services.Services, "service manager");
        foreach (var s in services.Names().Where(s => PsSemantics.Like(s, like)).ToList())
        {
            services.Stop(s);
            services.Delete(s);
        }
        var tasks = TweakServices.Need(c.Services.Tasks, "task scheduler");
        foreach (var t in tasks.Find(n => PsSemantics.Like(n, like))) tasks.Unregister(t);
        var title = $"*{activeSetup ?? name}*";
        foreach (var k in c.Registry.SubKeys(ActiveSetup))
            if (PsSemantics.Like(PsSemantics.Text(c.Registry.GetValue($@"{ActiveSetup}\{k}", "(default)")) ?? "", title))
                c.Registry.DeleteKey($@"{ActiveSetup}\{k}");
    }

    /// <summary>New-AkariShortcut: a Start menu shortcut for every user, its working folder the target's.</summary>
    public static void Shortcut(TweakContext c, string name, string target)
    {
        var link = Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), @"Microsoft\Windows\Start Menu\Programs", $"{name}.lnk");
        TweakServices.Need(c.Services.Shortcuts, "shortcut maker").Create(link, target, Path.GetDirectoryName(target));
    }

    /// <summary>Get-AkariWingetExe: the exe (a file pattern) of a portable winget package, unpacked under
    /// WinGet\Packages\&lt;id&gt;_&lt;source&gt; (the process's own LocalAppData, then Program Files); null when it isn't there.</summary>
    public static string? WingetExe(TweakContext c, string id, string filter)
    {
        string[] roots = [Path.Combine(c.Services.LocalAppData, @"Microsoft\WinGet\Packages"), Path.Combine(c.Services.ProgramFiles, @"WinGet\Packages")];
        foreach (var root in roots)
        {
            if (!Path.IsPathRooted(root) || !Directory.Exists(root)) continue;
            var d = Directory.EnumerateDirectories(root, $"{id}_*").Order(StringComparer.OrdinalIgnoreCase).FirstOrDefault();
            if (d is null) continue;
            var f = Directory.EnumerateFiles(d, filter, SearchOption.AllDirectories).FirstOrDefault();
            if (f is not null) return f;
        }
        return null;
    }

    /// <summary>Find-AkariProgram: the portable winget copy of the package, else the first exe (a file pattern) at most
    /// two folders down in Program Files, then Program Files (x86); null when it is not there.</summary>
    public static string? FindProgram(TweakContext c, string id, string exe)
    {
        if (WingetExe(c, id, exe) is { } portable) return portable;
        foreach (var root in new[] { c.Services.ProgramFiles, c.Services.ProgramFilesX86 })
            if (root.Length > 0 && Directory.Exists(root) && First(root, exe, 2) is { } found) return found;
        return null;
    }

    // Get-ChildItem -Recurse -Depth n -Filter -File | Select-Object -First 1: a folder's files, then each subfolder's
    private static string? First(string folder, string pattern, int depth)
    {
        try
        {
            if (Directory.EnumerateFiles(folder, pattern).FirstOrDefault() is { } f) return f;
            if (depth == 0) return null;
            foreach (var d in Directory.EnumerateDirectories(folder))
                if (First(d, pattern, depth - 1) is { } g) return g;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        return null;
    }

    /// <summary>Open-AkariWingetTool: a Tools check's program, its winget package installed first when it is missing,
    /// then started (not waited for).</summary>
    public static void OpenTool(TweakContext c, string id, string exe)
    {
        var path = FindProgram(c, id, exe);
        if (path is null)
        {
            TweakServices.Need(c.Services.Winget, "winget").Install(id);
            path = FindProgram(c, id, exe);
        }
        if (path is null) throw new InvalidOperationException($"{id} is installed, but {exe} was not found");
        Exe(c).Run(path, "", wait: false);
    }

    /// <summary>Get-AkariMsi: the products whose display name is like the pattern.</summary>
    public static IReadOnlyList<MsiProduct> Msi(TweakContext c, string like)
    {
        var found = new List<MsiProduct>();
        foreach (var root in UninstallRoots)
            foreach (var code in c.Registry.SubKeys(root))
                if (c.Registry.GetValue($@"{root}\{code}", "DisplayName") is string name && PsSemantics.Like(name, like))
                    found.Add(new MsiProduct(name, code));
        return found;
    }

    /// <summary>Uninstall-AkariMsi: every product like the pattern, silently, no restart.</summary>
    public static void UninstallMsi(TweakContext c, string like)
    {
        foreach (var p in Msi(c, like))
        {
            c.Log.Write($"Uninstalling: {p.Name}");
            Exe(c).Run(Path.Combine(System32(c), "msiexec.exe"), $"/x {p.Code} /qn /norestart");
        }
    }

    /// <summary>Invoke-AkariSelfUninstall: a Windows tool that uninstalls itself with /Uninstall and then shows a
    /// window (Remote Desktop Connection, Windows 10's Snipping Tool): started, its window closed once it appears (10 s
    /// at most).</summary>
    public static void SelfUninstall(TweakContext c, string exe, string process)
    {
        if (!File.Exists(exe)) return;
        try { Exe(c).Run(exe, "/Uninstall", wait: false); } catch (Exception e) when (e is not NotSupportedException) { }
        var processes = TweakServices.Need(c.Services.Processes, "process list");
        for (var i = 0; i < 100; i++)
        {
            c.Services.Sleep(TimeSpan.FromMilliseconds(100));
            if (processes.HasWindow(process)) break;
        }
        processes.Stop(process);
        c.Services.Sleep(TimeSpan.FromSeconds(1));
    }
}
