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
