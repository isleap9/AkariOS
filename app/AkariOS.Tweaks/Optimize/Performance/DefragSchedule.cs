using System.Text.RegularExpressions;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>src/Tweaks/Optimize/Performance/DefragSchedule.ps1's After, both ways: the scheduled task is what actually
/// runs, so every task whose name matches ScheduledDefrag is turned off on Apply and back on on Revert.</summary>
[TweakCode("performance-defrag-schedule-off")]
public sealed class DefragSchedule : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var tasks = FileData.Need(c.Services.Tasks, "Task Scheduler");
        foreach (var t in tasks.Find(n => Regex.IsMatch(n, "ScheduledDefrag", RegexOptions.IgnoreCase)))
            tasks.SetEnabled(t, mode == TweakMode.Revert);
    }
}
