using AkariOS.Core;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
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

/// <summary>The real one: the thread pool, then the window's dispatcher queue.</summary>
public sealed class DispatcherBackground(DispatcherQueue queue) : IBackground
{
    public void Run(Func<object?> work, Action<object?> done) =>
        Task.Run(work).ContinueWith(t => queue.TryEnqueue(() => done(t.IsCompletedSuccessfully ? t.Result : null)), TaskScheduler.Default);

    public void Post(Action action) => queue.TryEnqueue(() => action());
}

/// <summary>The shell's busy toast (Set-Busy): what runs now, shown at the bottom of the window.</summary>
public sealed partial class ShellState : ObservableObject
{
    [ObservableProperty]
    public partial bool IsBusy { get; set; }

    [ObservableProperty]
    public partial string BusyText { get; set; } = "";

    /// <summary>The page shown (its NavTable key; a search: "Search:…"), set by the window.</summary>
    [ObservableProperty]
    public partial string Page { get; set; } = "";

    /// <summary>A Run of Install AkariOS applies changes now: nothing else changes the PC until it is done.</summary>
    [ObservableProperty]
    public partial bool Locked { get; set; }

    public void SetBusy(bool on, string text = "")
    {
        BusyText = on ? text : "";
        IsBusy = on;
    }
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
        var r = await dialog.ShowAsync();
        return r == Microsoft.UI.Xaml.Controls.ContentDialogResult.Primary && box.Text.Trim().Length > 0 ? box.Text.Trim() : null;
    }
}

/// <summary>One-click's hand-off (Start-AkariOneClick): the preset Program runs in a console once the window closes.</summary>
public sealed class OneClickHandoff(Action<Core.Presets.Preset> start)
{
    public void Start(Core.Presets.Preset preset) => start(preset);
}
