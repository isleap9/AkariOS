using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DduManual.ps1: Prepare gets DDU ready while the network is up; in Safe Mode DDU's own
/// window opens and the Run goes on (back to normal) once it is closed. An Action: it opens a tool.</summary>
[TweakCode("tools-ddu-manual")]
public sealed class DduManual : ITweakCode
{
    public void Prepare(Tweak tweak, TweakContext c) => DriverSteps.InitializeDdu(c);

    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        TweakServices.Need(c.Services.Exe, "program runner").Run(DriverSteps.Ddu(c), "", wait: true, capture: false);
}
