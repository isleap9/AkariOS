using AkariOS.Core;
using AkariOS.Framework.Services;
using Microsoft.UI.Dispatching;

namespace AkariOS.App.Shell;

/// <summary>
/// Work off the UI thread and back on it. View models use only this, so tests run everything at once (in order).
/// </summary>
public interface IBackground
{
    /// <summary>Runs work off the UI thread; done gets its result back on the UI thread.</summary>
    void Run(Func<object?> work, Action<object?> done);

    /// <summary>Runs an action on the UI thread after the current one (out of a binding's setter, say).</summary>
    void Post(Action action);
}

/// <summary>Repeating timers on the UI thread (the ISO Builder's Massgrave watch): disposing one stops it. Tests tick
/// them by hand.</summary>
public interface ITimers
{
    IDisposable Every(TimeSpan interval, Action tick);
}

/// <summary>The real one: a DispatcherQueueTimer on the window's queue.</summary>
public sealed class DispatcherTimers(DispatcherQueue queue) : ITimers
{
    public IDisposable Every(TimeSpan interval, Action tick)
    {
        var timer = queue.CreateTimer();
        timer.Interval = interval;
        timer.IsRepeating = true;
        timer.Tick += (_, _) => tick();
        timer.Start();
        return new Stop(timer);
    }

    private sealed class Stop(DispatcherQueueTimer timer) : IDisposable
    {
        public void Dispose() => timer.Stop();
    }
}

/// <summary>A Run's progress, handed to the UI thread.</summary>
public sealed class PostedProgress(IBackground background, Action<Core.Runs.RunProgress> show) : IProgress<Core.Runs.RunProgress>
{
    public void Report(Core.Runs.RunProgress value) => background.Post(() => show(value));
}

/// <summary>The real one: the thread pool, then the window's dispatcher queue.</summary>
public sealed class DispatcherBackground(DispatcherQueue queue) : IBackground
{
    public void Run(Func<object?> work, Action<object?> done) =>
        Task.Run(work).ContinueWith(t => queue.TryEnqueue(() => done(t.IsCompletedSuccessfully ? t.Result : null)), TaskScheduler.Default);

    public void Post(Action action) => queue.TryEnqueue(() => action());
}

/// <summary>
/// The restore point rule (Get-AkariRestoreChoice): Downloads never; the rest once per session; when an AkariOS restore
/// point exists already, the user decides. Either way it is not asked again. False with no System Restore (tests).
/// </summary>
public sealed class RestoreRule(Engine engine, IDialogService dialogs)
{
    /// <summary>The session's restore point is made, or was declined.</summary>
    public bool Done { get; set; }

    public async Task<bool> ChooseAsync(string flow)
    {
        if (flow == "Downloads" || Done || engine.RestorePoints is not { } points) return false;
        if (points.Latest() is { } point)
        {
            var when = point.Date is { } d ? $" on {d:g}" : "";
            if (!await dialogs.ConfirmAsync("Restore point",
                    $"AkariOS already made a restore point{when}.\n\nCreate another restore point before these changes?", "Create one", "Skip"))
            {
                Done = true;
                return false;
            }
        }
        return true;
    }
}

/// <summary>A dialog that asks for a line of text (Read-AkariText): the trimmed text, or null when cancelled.</summary>
public interface ITextDialog
{
    Task<string?> AskAsync(string title, string message, string button);
}

/// <summary>The real one: a ContentDialog with a TextBox, over the window.</summary>
public sealed class ContentTextDialog(Func<Microsoft.UI.Xaml.XamlRoot?> root) : ITextDialog
{
    public async Task<string?> AskAsync(string title, string message, string button)
    {
        if (root() is not { } xamlRoot) return null;
        var box = new Microsoft.UI.Xaml.Controls.TextBox { Header = message };
        var dialog = new Microsoft.UI.Xaml.Controls.ContentDialog
        {
            XamlRoot = xamlRoot, Title = title, Content = box, PrimaryButtonText = button, CloseButtonText = "Cancel",
            DefaultButton = Microsoft.UI.Xaml.Controls.ContentDialogButton.Primary,
        };
        AkariDialogs.Style(dialog);
        var r = await dialog.ShowAsync();
        return r == Microsoft.UI.Xaml.Controls.ContentDialogResult.Primary && box.Text.Trim().Length > 0 ? box.Text.Trim() : null;
    }
}

/// <summary>One-click's hand-off (Start-AkariOneClick): the preset Program runs in a console once the window closes.</summary>
public sealed class OneClickHandoff(Action<Core.Presets.Preset> start)
{
    public void Start(Core.Presets.Preset preset) => start(preset);
}
