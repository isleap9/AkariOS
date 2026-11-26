using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;

namespace AkariOS.App.Shell;

/// <summary>
/// The numbers after a Run (About.ps1's Start-AkariMetricsAfter, plan 2026-11-26-new-features.md X6): on launch the
/// newest history record whose 'After' is due is read in the background; Windows up less than
/// <see cref="Metrics.Settle"/> = read once it has been. <see cref="Changed"/> tells Home to show them.
/// </summary>
public sealed class MetricsAfter(Engine engine, IBackground background)
{
    public event Action? Changed;

    /// <summary>Get-AkariMetricsShown: the newest record with both sides, or null.</summary>
    public HistoryRecord? Shown() => engine.History is { } h ? Metrics.Shown(h.All()) : null;

    /// <summary>Start-AkariMetricsAfter; delay: tests skip the wait.</summary>
    public async Task StartAsync(Func<TimeSpan, Task>? delay = null)
    {
        if (engine.History is not { ReadMetrics: { } read } h || engine.MetricsReader is not { } reader) return;
        var p = Metrics.Pending(h.All(), reader.LastBoot(), DateTime.Now);
        if (p is { State: "Wait" })
        {
            await (delay ?? Task.Delay)(Metrics.Settle - (DateTime.Now - reader.LastBoot()) + TimeSpan.FromSeconds(1));
            p = Metrics.Pending(h.All(), reader.LastBoot(), DateTime.Now);
        }
        if (p is not { State: "Due" } due) return;
        var done = new TaskCompletionSource();
        background.Run(() => { h.SetMetrics(due.Record.Path, "After", read()); return null; }, _ => done.SetResult());
        await done.Task;
        engine.Log.Write("Numbers after the last Run read: Home shows them");
        Changed?.Invoke();
    }
}
