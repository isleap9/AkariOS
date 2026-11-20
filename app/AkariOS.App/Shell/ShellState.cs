using System.Collections.ObjectModel;
using AkariOS.Core.Runs;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Shell;

/// <summary>Something running now (Set-Busy's label): its label and, for a Run, how far it has got.</summary>
public sealed class BusyWork(string label)
{
    public string Label { get; } = label;
    public int Done { get; internal set; }
    public int Total { get; internal set; }
    public string Step { get; internal set; } = "";
}

/// <summary>
/// The shell's toasts (Shell.ps1): the busy toast (Set-Busy: what runs now, its progress) and the result toasts
/// (Show-AkariToast), stacked at the bottom right. Every page's work goes through Begin / Report / End, so two things
/// running at once (an install from Downloads and a change from Optimize) each keep their line: the toast shows the
/// latest one, and closing the window names them all.
/// </summary>
public sealed partial class ShellState : ObservableObject
{
    /// <summary>At most this many result toasts; the oldest goes first.</summary>
    public const int MaxToasts = 4;

    private readonly List<BusyWork> _work = [];

    /// <summary>Something is running (the busy toast shows).</summary>
    [ObservableProperty]
    public partial bool IsBusy { get; private set; }

    /// <summary>The busy toast's line: the latest work's label, "(n of m): step" while a Run reports.</summary>
    [ObservableProperty]
    public partial string BusyText { get; private set; } = "";

    /// <summary>The busy toast's bar: no progress reported = a moving bar.</summary>
    [ObservableProperty]
    public partial bool Indeterminate { get; private set; } = true;

    /// <summary>0-100 while a Run reports.</summary>
    [ObservableProperty]
    public partial double ProgressValue { get; private set; }

    /// <summary>The page shown (its NavTable key; a search: "Search:…"), set by the window.</summary>
    [ObservableProperty]
    public partial string Page { get; set; } = "";

    /// <summary>A Run of Install AkariOS or Remove apps changes the PC now: Optimize's changes and Downloads' installs
    /// wait in their queues until it is done.</summary>
    [ObservableProperty]
    public partial bool Locked { get; set; }

    /// <summary>The result toasts, newest first.</summary>
    public ObservableCollection<Toast> Toasts { get; } = [];

    /// <summary>What runs now, oldest first.</summary>
    public IReadOnlyList<BusyWork> Work => _work;

    /// <summary>Work starts: the busy toast shows its label.</summary>
    public BusyWork Begin(string label)
    {
        var w = new BusyWork(label);
        _work.Add(w);
        Show();
        return w;
    }

    /// <summary>A Run's progress (Set-AkariStatusProgress).</summary>
    public void Report(BusyWork work, RunProgress p) => Report(work, p.Done, p.Total, p.Step);

    public void Report(BusyWork work, int done, int total, string step = "")
    {
        (work.Done, work.Total, work.Step) = (done, total, step);
        Show();
    }

    /// <summary>The work is done (ended twice is harmless).</summary>
    public void End(BusyWork? work)
    {
        if (work is not null && _work.Remove(work)) Show();
    }

    private void Show()
    {
        var w = _work.Count > 0 ? _work[^1] : null;
        IsBusy = w is not null;
        BusyText = w is null ? "" : ProgressText(w.Label, w.Done, w.Total, w.Step);
        Indeterminate = w is not { Total: > 0 };
        ProgressValue = w is { Total: > 0 } ? Math.Min(1, (double)w.Done / w.Total) * 100 : 0;
    }

    /// <summary>Get-AkariProgressText: "Label (n of m): step", n being the one running now.</summary>
    public static string ProgressText(string label, int done, int total, string step)
    {
        if (total <= 0) return label;
        var t = $"{label} ({Math.Min(done + 1, total)} of {total})";
        return step.Length > 0 ? $"{t}: {step}" : t;
    }

    /// <summary>Show-AkariToast: a result, newest on top; it goes by itself after <see cref="Toast.Seconds"/> (the
    /// window's timer) or with its close button. An action (Restart now, Open folder) closes it too.</summary>
    public Toast Toast(string title, string text = "", InfoBarSeverity severity = InfoBarSeverity.Success, string? actionText = null, Action? action = null)
    {
        var t = new Toast(title, text, severity, actionText, action, Dismiss);
        Toasts.Insert(0, t);
        while (Toasts.Count > MaxToasts) Toasts.RemoveAt(Toasts.Count - 1);
        return t;
    }

    public void Dismiss(Toast t) => Toasts.Remove(t);
}

/// <summary>A result toast (Show-AkariToast): title, line, severity, an optional action.</summary>
public sealed partial class Toast
{
    private readonly Action? _action;
    private readonly Action<Toast> _dismiss;

    internal Toast(string title, string text, InfoBarSeverity severity, string? actionText, Action? action, Action<Toast> dismiss)
    {
        (Title, Text, Severity, ActionText, _action, _dismiss) = (title, text, severity, actionText ?? "", action, dismiss);
    }

    public string Title { get; }
    public string Text { get; }
    public InfoBarSeverity Severity { get; }
    public string ActionText { get; }
    public bool HasAction => _action is not null && ActionText.Length > 0;

    /// <summary>How long it stays: longer with an action or a failure to read.</summary>
    public int Seconds => HasAction || Severity is InfoBarSeverity.Error or InfoBarSeverity.Warning ? 10 : 5;

    [RelayCommand]
    public void Act()
    {
        _dismiss(this);
        _action?.Invoke();
    }

    [RelayCommand]
    public void Close() => _dismiss(this);
}
