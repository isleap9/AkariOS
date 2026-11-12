using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DduClean.ps1: Prepare gets DDU ready while the network is up; in Safe Mode DDU
/// removes every GPU driver and the Realtek / Sound Blaster audio drivers, then restarts (Restarts). An Action: removed
/// drivers can't be put back.</summary>
[TweakCode("tools-ddu-clean")]
public sealed class DduClean : ITweakCode
{
    public void Prepare(Tweak tweak, TweakContext c) => DriverSteps.InitializeDdu(c);

    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        TweakServices.Need(c.Services.Exe, "program runner").Run(DriverSteps.Ddu(c), OneClick.Drivers.DduClean.Arguments, wait: true, capture: false);
}
