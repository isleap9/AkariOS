using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.OneClick.Prepare;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>The steps the Tools › Drivers Actions share (src/Tweaks/Tools/Drivers/Files/Drivers.ps1). So far DDU's (N7);
/// the driver installs come with N8.</summary>
internal static class DriverSteps
{
    public const string SettingsFile = "src/Tweaks/OneClick/Prepare/Files/ddu-settings.xml";

    /// <summary>Get-DriverSevenZip: 7-Zip's 7z.exe, installed from winget when missing.</summary>
    public static string SevenZip(TweakContext c)
    {
        var sevenZip = Path.Combine(TweakServices.Folder(c.Services.ProgramFiles, "Program Files"), "7-Zip", "7z.exe");
        if (!File.Exists(sevenZip)) TweakServices.Need(c.Services.Winget, "winget").Install("7zip.7zip");
        if (!File.Exists(sevenZip)) throw new InvalidOperationException("7-Zip is not installed, and winget could not install it");
        return sevenZip;
    }

    /// <summary>Expand-DriverArchive: the archive unpacked into the folder, emptied first.</summary>
    public static void Expand(TweakContext c, string archive, string dir)
    {
        if (Directory.Exists(dir))
        {
            // Remove-Item -Force: read-only files go too
            foreach (var f in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
            Directory.Delete(dir, recursive: true);
        }
        if (TweakServices.Need(c.Services.Exe, "program runner").Run(SevenZip(c), ExeArgs.Join("x", archive, $"-o{dir}", "-y")).ExitCode != 0)
            throw new InvalidOperationException($"{Path.GetFileName(archive)} could not be unpacked");
    }

    private static string Temp(TweakContext c) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "Temp");

    /// <summary>Initialize-DriverDdu: DDU in Windows\Temp\ddu with One-click's settings, read only. A Prepare step: it
    /// needs the network.</summary>
    public static void InitializeDdu(TweakContext c)
    {
        var dir = Path.Combine(Temp(c), "ddu");
        var exe = Path.Combine(Temp(c), "ddu.exe");
        TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save("ddu.exe", exe);
        Expand(c, exe, dir);
        DduSettings.Write(c, Path.Combine(dir, "Settings", "Settings.xml"), SettingsFile);
    }

    /// <summary>Get-DriverDdu: DDU's program, ready from Prepare.</summary>
    public static string Ddu(TweakContext c)
    {
        var exe = Path.Combine(Temp(c), "ddu", "Display Driver Uninstaller.exe");
        if (!File.Exists(exe)) throw new InvalidOperationException("DDU is not ready (its download before the restart failed)");
        return exe;
    }
}
