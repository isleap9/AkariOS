using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Setup;

/// <summary>src/Tweaks/Tools/Setup/RestorePoint.ps1: an "AkariOS setup" restore point now (System Protection turned on
/// if needed, the 24 hour throttle lifted once: RestorePoints.Create). Refused = the Action fails with Windows' reason.
/// An Action: nothing to undo.</summary>
[TweakCode("oneclick-restore-point")]
public sealed class RestorePoint : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var r = new RestorePoints(TweakServices.Need(c.Services.SystemRestore, "System Restore"), c.Registry, c.Log).Create("AkariOS setup");
        if (!r.Ok) throw new InvalidOperationException(r.Message);
    }
}
