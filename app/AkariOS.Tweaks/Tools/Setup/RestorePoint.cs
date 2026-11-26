using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Setup;

/// <summary>src/Tweaks/Tools/Setup/RestorePoint.ps1: an "AkariOS setup" restore point now (System Protection turned on
/// if needed, the 24 hour throttle lifted once: RestorePoints.Create). Refused = the Action fails with Windows' reason,
/// but Skipped when an AkariOS point from the last 24 hours is there (One-click's own, made as it started).
/// An Action: nothing to undo.</summary>
[TweakCode("oneclick-restore-point")]
public sealed class RestorePoint : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var points = new RestorePoints(TweakServices.Need(c.Services.SystemRestore, "System Restore"), c.Registry, c.Log);
        var r = points.Create("AkariOS setup");
        if (r.Ok) return;
        // WMI's CreationTime is local time
        if (points.Latest()?.Date is { } made && c.Services.UtcNow().ToLocalTime() - made < TimeSpan.FromHours(24))
            throw new SkippedException($"Windows keeps one restore point a day: the AkariOS one from {made:yyyy-MM-dd HH:mm} stays");
        throw new InvalidOperationException(r.Message);
    }
}
