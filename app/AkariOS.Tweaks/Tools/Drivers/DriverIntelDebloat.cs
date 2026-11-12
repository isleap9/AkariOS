using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DriverIntelDebloat.ps1: the newest Intel graphics package (gfx_win_*.exe) in
/// Downloads, unpacked to %SystemDrive%\inteldriver, installed with no extras; Intel Graphics Software added without its
/// startup entry; the firmware update, HDCP and controller services removed. An Action: DDU (tools-ddu-clean) removes it.</summary>
[TweakCode("tools-driver-intel-debloat")]
public sealed class DriverIntelDebloat : ITweakCode
{
    public static readonly string[] Services = ["IntelGFXFWupdateTool", "cplspcon", "CtaChildDriver", "GSCAuxDriver", "GSCx64"];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var pkg = DriverSteps.Package(c, "gfx_win_*.exe", "", DriverSteps.IntelPage, "Intel");
        var drive = TweakServices.Folder(c.Services.SystemDrive, "system drive");
        var dir = Path.Combine(drive, "inteldriver");
        DriverSteps.Expand(c, pkg, dir);
        c.Log.Write("Installing the Intel driver");
        DriverSteps.Install(c, Path.Combine(dir, "Installer.exe"), "Intel installer", "-f", "--noExtras", "--terminateProcesses", "-s");
        var extras = Path.Combine(dir, "Resources", "Extras");
        var igs = Directory.Exists(extras) ? Directory.EnumerateFiles(extras, "IntelGraphicsSoftware_*.exe").FirstOrDefault() : null;
        if (igs is not null) TweakServices.Need(c.Services.Exe, "program runner").Run(igs, "/s");
        // "Intel(R) Graphics Software" with the registered sign
        AppSetup.RemoveStartup(c, "Intel® Graphics Software");
        DriverSteps.RemoveServices(c, Services);
        var processes = TweakServices.Need(c.Services.Processes, "process list");
        foreach (var p in new[] { "IntelGraphicsSoftware", "PresentMonService" }) processes.Stop(p);
        DriverSteps.Delete(pkg, dir, Path.Combine(drive, "Intel"));
    }
}
