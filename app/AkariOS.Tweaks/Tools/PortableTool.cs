using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools;

/// <summary>Programs the Tools download and start (the polling tests, the repair and setup tools).</summary>
internal static class PortableTool
{
    /// <summary>A one-file tool under Program Files (x86): downloaded from AkariOS-Files when it is missing, a Start menu
    /// shortcut made (again), then started.</summary>
    public static void Open(TweakContext c, string file, string underX86, string shortcut)
    {
        var exe = Path.Combine(TweakServices.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"), underX86);
        if (!File.Exists(exe)) TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save(file, exe);
        AppSetup.Shortcut(c, shortcut, exe);
        ShellStart.Run(c, exe);
    }

    /// <summary>Windows\Temp\&lt;name&gt;: where the blocks put a tool they download and start.</summary>
    public static string Temp(TweakContext c, string name) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "Temp", name);

    /// <summary>Invoke-WebRequest -OutFile, then Start-Process: a vendor's own download, started.</summary>
    public static void DownloadAndStart(TweakContext c, string url, string exe)
    {
        TweakServices.Need(c.Services.Http, "downloader").Download(url, exe);
        ShellStart.Run(c, exe);
    }
}
