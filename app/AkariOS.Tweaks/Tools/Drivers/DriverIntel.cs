using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DriverIntel.ps1: Intel's driver downloads, newest first. An Action: the driver
/// install is Intel's own.</summary>
[TweakCode("tools-driver-intel")]
public sealed class DriverIntel : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, DriverSteps.IntelPage);
}
