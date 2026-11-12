using System.IO.Compression;
using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/ControllerOverclock.ps1: hidusbf from AkariOS-Files unpacked to Program Files (x86)\
/// hidusbf (its versioned folder's contents moved up), its driver installed (setupapi's InstallHinfSection), a Start menu
/// shortcut to its Setup, which opens. An Action: hidusbf's own Setup removes it.</summary>
[TweakCode("tools-controller-overclock")]
public sealed class ControllerOverclock : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var root = Path.Combine(TweakServices.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"), "hidusbf");
        var zip = DriverSteps.Temp(c, "hidusbf.zip");
        TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save("hidusbf.zip", zip);
        ZipFile.ExtractToDirectory(zip, root, overwriteFiles: true);
        // the zip holds one versioned folder ("hidusbf (BB11.5.25)"): its contents go up into hidusbf
        foreach (var d in Directory.EnumerateDirectories(root, "hidusbf*").ToList())
        {
            foreach (var e in Directory.EnumerateFileSystemEntries(d).ToList())
            {
                var to = Path.Combine(root, Path.GetFileName(e));
                if (Directory.Exists(e)) Directory.Move(e, to);
                else File.Move(e, to, overwrite: true);
            }
            DriverSteps.Delete(d);
        }
        var setup = Path.Combine(root, "DRIVER", "Setup.exe");
        var system32 = Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32");
        TweakServices.Need(c.Services.Exe, "program runner").Run(Path.Combine(system32, "rundll32.exe"),
            ExeArgs.Join($@"setupapi.dll,InstallHinfSection DefaultInstall 132 {root}\DRIVER\HIDUSBF_AS.INF"));
        AppSetup.Shortcut(c, "hidusbf Setup", setup);
        ShellStart.Run(c, setup);
    }
}
