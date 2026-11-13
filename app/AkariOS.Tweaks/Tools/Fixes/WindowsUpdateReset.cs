using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Fixes;

/// <summary>
/// src/Tweaks/Tools/Fixes/WindowsUpdateReset.ps1 (winutil's Invoke-WPFFixesUpdate without its Aggressive steps and its
/// blanket policy wipe): the update services stopped, the BITS queue, an old Download.bak and the old log deleted, the
/// Download folder moved to Download.bak, the DLLs registered again, the WSUS ids and update policy values removed,
/// Winsock / WinHTTP proxy / IP reset, the BITS jobs cleared, the services set to Manual and started, a scan asked for.
/// The service, DLL and value lists are read out of the file. A service that won't stop or start is left as it is
/// (-ErrorAction SilentlyContinue). An Action that wants a restart.
/// </summary>
[TweakCode("tools-fix-windows-update")]
public sealed class WindowsUpdateReset : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var s = c.Services;
        var windows = TweakServices.Folder(s.Windows, "Windows");
        var sys = Path.Combine(windows, "System32");
        var exe = TweakServices.Need(s.Exe, "program runner");
        var control = TweakServices.Need(s.Services, "service control");
        var services = FileData.AssignedList(c.Files, tweak.Source, "services");
        void Run(string program, params string[] args) => exe.Run(Path.Combine(sys, program), ExeArgs.Join(args));

        c.Log.Write("Windows Update reset: stopping its services");
        foreach (var n in services) Quietly(() => control.Stop(n));

        c.Log.Write("Windows Update reset: clearing the BITS queue and the download cache");
        var download = Path.Combine(windows, "SoftwareDistribution", "Download");
        SystemPaths.Remove([
            Path.Combine(TweakServices.Folder(s.ProgramData, "ProgramData"), "Microsoft", "Network", "Downloader", "qmgr*.dat"),
            download + ".bak", Path.Combine(windows, "WindowsUpdate.log")]);
        if (Directory.Exists(download)) Directory.Move(download, download + ".bak");

        c.Log.Write("Windows Update reset: registering its DLLs again");
        foreach (var d in FileData.AssignedList(c.Files, tweak.Source, "dlls")) Run("regsvr32.exe", "/s", d);

        c.Log.Write("Windows Update reset: clearing the WSUS ids and the update policies");
        foreach (var v in FileData.AssignedList(c.Files, tweak.Source, "values"))
        {
            var (key, name) = (v.Split('|')[0], v.Split('|')[1]);
            c.Registry.RemoveValue(key, name);
        }

        c.Log.Write("Windows Update reset: resetting Winsock, the WinHTTP proxy and the IP stack");
        Run("netsh.exe", "winsock", "reset");
        Run("netsh.exe", "winhttp", "reset", "proxy");
        Run("netsh.exe", "int", "ip", "reset");
        Run("bitsadmin.exe", "/reset", "/allusers");

        c.Log.Write("Windows Update reset: starting its services");
        foreach (var n in services)
        {
            c.Registry.SetValue($@"HKLM:\SYSTEM\CurrentControlSet\Services\{n}", "Start", 3u, "DWord");
            Quietly(() => control.Start(n));
        }
        Run("wuauclt.exe", "/resetauthorization", "/detectnow");
        c.Log.Write("Windows Update reset: done. Restart Windows to finish.");
    }

    // -ErrorAction SilentlyContinue: a service that isn't there or won't change is left as it is
    private static void Quietly(Func<bool> act)
    {
        try { act(); }
        catch (Exception) { }
    }
}
