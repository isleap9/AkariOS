using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DriverNvidiaDebloat.ps1: the latest GeForce driver downloaded and unpacked, NVIDIA
/// App, telemetry, ShadowPlay, PhysX, HD Audio and the rest taken out, the driver installed silently, the NVIDIA Control
/// Panel added (AkariOS-Files' nvp.appx). An Action: DDU (tools-ddu-clean) removes it.</summary>
[TweakCode("tools-driver-nvidia-debloat")]
public sealed class DriverNvidiaDebloat : ITweakCode
{
    /// <summary>What the stripped package leaves out (under the unpacked folder).</summary>
    public static readonly string[] Stripped =
    [
        "Display.Nview", "FrameViewSDK", "HDAudio", "MSVCRT", "NvApp.MessageBus", "NvBackend", "NvContainer", "NvCpl", "NvDLISR",
        "NVPCF", "NvTelemetry", "NvVAD", "PhysX", "PPC", "ShadowPlay", @"NvApp\CEF", @"NvApp\osc", @"NvApp\Plugins", @"NvApp\UpgradeConsent",
        @"NvApp\www", @"NvApp\7z.dll", @"NvApp\7z.exe", @"NvApp\DarkModeCheck.exe", @"NvApp\InstallerExtension.dll", @"NvApp\NvApp.nvi",
        @"NvApp\NvAppApi.dll", @"NvApp\NvAppExt.dll", @"NvApp\NvConfigGenerator.dll",
    ];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var exe = DriverSteps.Temp(c, "nvidiadriver.exe");
        var dir = DriverSteps.Temp(c, "nvidiadriver");
        TweakServices.Need(c.Services.Http, "downloader").Download(DriverSteps.NvidiaUrl(c), exe);
        DriverSteps.Expand(c, exe, dir);
        DriverSteps.Delete([.. Stripped.Select(p => Path.Combine(dir, p))]);
        c.Log.Write("Installing the NVIDIA driver");
        DriverSteps.Install(c, Path.Combine(dir, "setup.exe"), "NVIDIA setup", "-s", "-noreboot", "-noeula", "-clean");
        var panel = DriverSteps.Temp(c, "nvp.appx");
        TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save("nvp.appx", panel);
        TweakServices.Need(c.Services.Apps, "Store app installer").Add(panel);
        DriverSteps.Delete(exe, Path.Combine(TweakServices.Folder(c.Services.SystemDrive, "system drive"), "NVIDIA"));
    }
}
