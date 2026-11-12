using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.OneClick.Prepare;

/// <summary>src/Tweaks/OneClick/Prepare/DduPrepare.ps1: Display Driver Uninstaller downloaded (AkariOS-Files), unpacked
/// by 7-Zip to Windows\Temp\ddu, its settings from Files/ddu-settings.xml left read only so DDU keeps them. An Action:
/// it only gets a tool ready. Needs 7-Zip (install-7-zip runs before it).</summary>
[TweakCode("oneclick-ddu-prepare")]
public sealed class DduPrepare : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var temp = Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "Temp");
        var dir = Path.Combine(temp, "ddu");
        var exe = Path.Combine(temp, "ddu.exe");
        TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save("ddu.exe", exe);
        var sevenZip = Path.Combine(TweakServices.Folder(c.Services.ProgramFiles, "Program Files"), "7-Zip", "7z.exe");
        if (!File.Exists(sevenZip)) throw new InvalidOperationException("7-Zip is not installed (install-7-zip)");
        if (TweakServices.Need(c.Services.Exe, "program runner").Run(sevenZip, ExeArgs.Join("x", exe, $"-o{dir}", "-y")).ExitCode != 0)
            throw new InvalidOperationException("DDU could not be unpacked");
        DduSettings.Write(c, Path.Combine(dir, "Settings", "Settings.xml"), $"{TweakContext.FolderOf(tweak)}/Files/ddu-settings.xml");
    }
}

/// <summary>DDU's settings file: copied from the src/ file (byte for byte) over a read-only one, then left read only.</summary>
internal static class DduSettings
{
    public static void Write(TweakContext c, string cfg, string source)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(cfg)!);
        if (File.Exists(cfg)) File.SetAttributes(cfg, File.GetAttributes(cfg) & ~FileAttributes.ReadOnly);
        File.WriteAllBytes(cfg, c.Files.ReadBytes(source));
        File.SetAttributes(cfg, File.GetAttributes(cfg) | FileAttributes.ReadOnly);
    }
}
