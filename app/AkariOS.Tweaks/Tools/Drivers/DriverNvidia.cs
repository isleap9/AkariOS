using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DriverNvidia.ps1: the latest WHQL GeForce driver (NVIDIA's lookup) downloaded and its
/// installer started. An Action: a driver install, done by NVIDIA's own installer.</summary>
[TweakCode("tools-driver-nvidia")]
public sealed class DriverNvidia : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        PortableTool.DownloadAndStart(c, DriverSteps.NvidiaUrl(c), DriverSteps.Temp(c, "nvidiadriver.exe"));
}
