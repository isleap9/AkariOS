using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/EventLogs.ps1 (ZOICWARE): every event log wevtutil lists, cleared. An Action:
/// cleared events can't come back.</summary>
[TweakCode("cleanup-event-logs")]
public sealed class EventLogs : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var wevtutil = TweakServices.Need(c.Services.Wevtutil, "wevtutil");
        var n = 0;
        foreach (var log in wevtutil.Run("el").Where(l => l.Length > 0))
        {
            wevtutil.Run("cl", log);
            n++;
        }
        c.Log.Write($"Cleared {n} event logs");
    }
}
