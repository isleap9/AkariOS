using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.ScheduledTasks;

/// <summary>src/Tweaks/Advanced/Scheduled tasks/RemoveScheduledTasks.ps1 (Remove-AkariScheduledTasks): every task but
/// SvcRestartTask and MsCtfMonitor (text input) is unregistered; the protected ones Windows keeps are skipped. An
/// Action: a deleted task can't be put back.</summary>
[TweakCode("advanced-remove-scheduled-tasks")]
public sealed class RemoveScheduledTasks : ITweakCode
{
    public static IReadOnlyList<string> Keep { get; } = ["SvcRestartTask", "MsCtfMonitor"];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var tasks = TweakServices.Need(c.Services.Tasks, "task scheduler");
        var n = tasks.Find(name => !Keep.Contains(name)).Count(t => tasks.Unregister(t));
        c.Log.Write($"Removed {n} scheduled tasks");
    }
}
