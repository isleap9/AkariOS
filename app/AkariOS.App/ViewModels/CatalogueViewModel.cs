using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.ViewModels;

/// <summary>
/// Optimize, the Catalogue (src/UI/CataloguePage.ps1; the WPF app's CatalogueView), one per app: the cards (kept per
/// Tweak), their States read in the background one by one, and every change. A change acts right away: confirmed when
/// needed, then queued and run one at a time, the session's restore point first; a Safe Mode Tweak outside Safe Mode
/// waits in the Safe Mode bar instead; Explorer and PC restarts collect in the restart bar.
/// </summary>
public sealed partial class CatalogueViewModel : ObservableObject
{
    private readonly Engine _engine;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly ShellState _shell;
    private readonly RestoreRule _restore;
    private readonly ActivityLog _activity;
    private readonly Dictionary<string, TweakCardViewModel> _cards = [];
    private readonly Queue<Job> _queue = new();
    private readonly HashSet<string> _explorer = [];
    private readonly HashSet<string> _reboot = [];
    private IReadOnlyList<Tweak>? _tweaks;
    private IReadOnlyList<CatalogueSection>? _sections;

    public CatalogueViewModel(Engine engine, IBackground background, IDialogService dialogs, ShellState shell, RestoreRule restore, ActivityLog activity)
    {
        _activity = activity;
        _engine = engine;
        _background = background;
        _dialogs = dialogs;
        _shell = shell;
        _restore = restore;
        // a Run of Install AkariOS or Remove apps is done: the changes that waited for it run now
        _shell.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ShellState.Locked) && !_shell.Locked) _ = Guard(NextAsync());
        };
    }

    /// <summary>The Tweaks it lists (this PC's).</summary>
    public IReadOnlyList<Tweak> Tweaks => _tweaks ??= Catalogue.Tweaks(_engine.Loaded.Tweaks, _engine.System);

    /// <summary>The Sections with their Category pages.</summary>
    public IReadOnlyList<CatalogueSection> Sections => _sections ??= Catalogue.Pages(Tweaks);

    /// <summary>Safe Mode changes waiting for "Restart and apply" (one Run in phases).</summary>
    public Dictionary<string, SafeChange> SafePending { get; } = [];

    /// <summary>A Tweak was applied or reverted here (Home's "changes applied" is read again).</summary>
    public event Action? Applied;

    /// <summary>A Run elsewhere (Install AkariOS) changed Tweaks: Home reads its count again.</summary>
    public void NotifyApplied() => Applied?.Invoke();

    /// <summary>A change runs now (one at a time, Explorer's and the PC's restart included).</summary>
    public bool Running { get; private set; }

    /// <summary>Changes waiting in the queue (not the one running).</summary>
    public int Queued => _queue.Count;

    private BusyWork? _busy;

    [ObservableProperty]
    public partial bool SafeBarOpen { get; private set; }

    [ObservableProperty]
    public partial string SafeBarText { get; private set; } = "";

    [ObservableProperty]
    public partial bool RestartBarOpen { get; private set; }

    [ObservableProperty]
    public partial string RestartBarText { get; private set; } = "";

    [ObservableProperty]
    public partial bool CanRestartExplorer { get; private set; }

    [ObservableProperty]
    public partial bool CanRestartPc { get; private set; }

    /// <summary>A card, made the first time.</summary>
    private readonly List<TweakCardViewModel> _highlighted = [];

    /// <summary>The search's query marked in these cards' names; every other card shown plain (a card is shared by
    /// every page that shows it).</summary>
    public void Highlight(IEnumerable<TweakCardViewModel> cards, string query)
    {
        foreach (var c in _highlighted) c.Query = "";
        _highlighted.Clear();
        if (query.Trim().Length == 0) return;
        foreach (var c in cards)
        {
            c.Query = query.Trim();
            _highlighted.Add(c);
        }
    }

    public TweakCardViewModel Card(Tweak t) =>
        _cards.TryGetValue(t.Id, out var c) ? c : _cards[t.Id] = new TweakCardViewModel(t, _engine.States.DefaultFor(t),
            (card, mode, value) => _background.Post(() => _ = Guard(ChangeAsync(card.Tweak, mode, value))));

    /// <summary>The search box's suggestions (Get-AkariSuggestions): up to six Tweaks whose name or description has it.</summary>
    public IReadOnlyList<Tweak> Suggest(string query) =>
        query.Trim().Length == 0 ? [] : Catalogue.List(Tweaks, "", query.Trim()).Take(6).ToList();

    private void Show(TweakCardViewModel c) => c.Update(SafePending.GetValueOrDefault(c.Tweak.Id));

    // ---- States, read in the background

    /// <summary>The Toggles' and Choices' States, read off the UI thread one after another (a card says "Reading…"
    /// until its own arrives); cards busy with a change are left alone.</summary>
    public void ReadStates(IEnumerable<Tweak> tweaks)
    {
        var queue = new Queue<TweakCardViewModel>();
        foreach (var t in tweaks.Where(t => t.Kind != TweakKind.Action))
        {
            var c = Card(t);
            if (c.Busy != CatalogueBusy.None) continue;
            c.Busy = CatalogueBusy.Reading;
            c.Error = "";
            Show(c);
            queue.Enqueue(c);
        }
        ReadNext(queue);
    }

    private void ReadNext(Queue<TweakCardViewModel> queue)
    {
        if (!queue.TryDequeue(out var c)) return;
        _background.Run(() => Read(c.Tweak), r =>
        {
            var read = r as StateRead ?? new StateRead(TweakState.Unknown, null);
            if (c.Busy == CatalogueBusy.Reading)
            {
                (c.State, c.Current, c.Busy) = (read.State, read.Current, CatalogueBusy.None);
                Show(c);
            }
            ReadNext(queue);
        });
    }

    private sealed record StateRead(TweakState State, object? Current);

    // a State that can't be read is Unknown
    private StateRead Read(Tweak t)
    {
        var state = TweakState.Unknown;
        try { state = _engine.States.Of(t); } catch (Exception) { }
        object? current = null;
        if (t.Kind == TweakKind.Choice) try { current = _engine.States.ChoiceValue(t); } catch (Exception) { }
        return new StateRead(state, current);
    }

    // ---- changes: right away, one at a time

    /// <summary>A card's control was used (Invoke-AkariCatalogueChange): asks first when the change needs it, then
    /// queues it; a Safe Mode Tweak outside Safe Mode waits in the Safe Mode bar instead.</summary>
    public async Task ChangeAsync(Tweak t, TweakMode mode, object? value = null)
    {
        var c = Card(t);
        if (c.Busy != CatalogueBusy.None || c.NotNative is not null) { Show(c); return; }
        // while a Run of Install AkariOS or Remove apps applies, the change waits in the queue (Waiting…) and runs
        // after it (the plan's W6 decision)
        if (mode == TweakMode.Apply)
        {
            var target = t.Kind == TweakKind.Choice ? value ?? t.Recommended : Selection.Optimized;
            if (Selection.ConfirmText(t, target, c.WindowsDefault) is { } q && !await _dialogs.ConfirmAsync(t.Name, q, "Continue")) { Show(c); return; }
        }
        c.Error = "";
        if (t.SafeMode && !_engine.InSafeMode())
        {
            // the prototype's question: Restart and apply now, Later (it waits in the Safe Mode bar), or Cancel
            var now = false;
            if (mode == TweakMode.Apply && !SafePending.ContainsKey(t.Id))
            {
                var r = await _dialogs.ShowAsync($"{t.Name}?", $"{t.Description}\n\nThis change applies in Safe Mode: AkariOS restarts into it, applies it and restarts back.",
                    "Restart and apply", "Later", "Cancel");
                if (r == ContentDialogResult.None) { Show(c); return; }
                now = r == ContentDialogResult.Primary;
            }
            Catalogue.SetSafePending(SafePending, t, c.State, mode, value, c.Current);
            Show(c);
            UpdateBars();
            if (now) StartSafeRun();
            else if (SafePending.ContainsKey(t.Id) && mode == TweakMode.Apply)
                _shell.Toast("Waiting for Safe Mode", $"\"{t.Name}\" applies the next time AkariOS restarts into Safe Mode.", InfoBarSeverity.Informational);
            return;
        }
        c.Busy = CatalogueBusy.Waiting;
        Show(c);
        var verb = t.Kind == TweakKind.Action ? t.Button.ToLowerInvariant() : mode == TweakMode.Apply ? "apply" : "revert";
        Enqueue($"{t.Name}: {verb}", !(t.Kind == TweakKind.Action && t.Button is "Check" or "Open"),
            () => { c.Busy = CatalogueBusy.Running; Show(c); },
            () =>
            {
                Outcome? o = null;
                try { o = _engine.Runner.Run(t, mode, value); }
                catch (Exception e) { _engine.Log.WriteFile($"Error: {t.Id}: {e}"); }
                return new ChangeDone(o, Read(t));
            },
            r => Changed(c, r));
    }

    private sealed record ChangeDone(Outcome? Outcome, StateRead Read);

    /// <summary>A queued change: its busy label, whether it gets the session's restore point first, what to show when
    /// it starts, the work (off the UI thread) and what to show with its result.</summary>
    private sealed record Job(string Label, bool Restore, Action Begin, Func<object?> Work, Action<object?> Done);

    /// <summary>Queues a change (a Tweak's, a service's, a task's): run one at a time, after the ones before it.</summary>
    public void Enqueue(string label, bool restore, Action begin, Func<object?> work, Action<object?> done)
    {
        _queue.Enqueue(new Job(label, restore, begin, work, done));
        _ = Guard(NextAsync());
    }

    // the next change; the session's first one gets an AkariOS restore point first (not a Check / Open button), and
    // goes on without one when Windows refuses
    private async Task NextAsync()
    {
        if (Running || _shell.Locked || !_queue.TryDequeue(out var job)) return;
        Running = true;
        job.Begin();
        var restore = job.Restore && await _restore.ChooseAsync("Optimize");
        if (restore) _restore.Done = true;
        _busy = _shell.Begin(job.Label);
        _engine.Log.Write(job.Label);
        _background.Run(() =>
        {
            if (restore && _engine.RestorePoints?.Create("AkariOS") is { Ok: false })
                _engine.Log.Write("Warning: going on without a restore point");
            return job.Work();
        }, r =>
        {
            Running = false;
            _shell.End(_busy);
            job.Done(r);
            UpdateBars();
            _ = Guard(NextAsync());
        });
    }

    // a Tweak's change is done: the card shows its State read back, a failure, the restarts it needs
    private void Changed(TweakCardViewModel c, object? r)
    {
        var t = c.Tweak;
        c.Busy = CatalogueBusy.None;
        if (r is ChangeDone d)
        {
            (c.State, c.Current) = (d.Read.State, d.Read.Current);
            if (d.Outcome is null) c.Error = "it stopped before its change (see the log)";
            else if (d.Outcome.Kind == OutcomeKind.Failed) c.Error = d.Outcome.Message;
            else if (d.Outcome.Kind is OutcomeKind.Applied or OutcomeKind.Reverted)
            {
                _activity.Add($"{(d.Outcome.Kind == OutcomeKind.Applied ? "Applied" : "Reverted")} \"{t.Name}\"", "Optimize", 1, t.Category);
                Applied?.Invoke();
                if (t.Explorer) _explorer.Add(t.Id);
                if (t.Reboot) _reboot.Add(t.Id);
            }
        }
        else c.Error = "it stopped before its change (see the log)";
        Show(c);
    }

    // a change's own failure is in its card; anything else in akari.log
    private async Task Guard(Task task)
    {
        try { await task; }
        catch (Exception e)
        {
            _engine.Log.WriteFile($"Error: UI: {e}");
            Running = false;
            _shell.End(_busy);
        }
    }

    // ---- the bars

    private void UpdateBars()
    {
        SafeBarText = Catalogue.SafeBarText(SafePending.Count);
        SafeBarOpen = SafePending.Count > 0;
        var lines = Catalogue.RestartBarText(_explorer.Count, _reboot.Count);
        RestartBarText = string.Join(" ", lines);
        RestartBarOpen = lines.Count > 0;
        CanRestartExplorer = _explorer.Count > 0;
        CanRestartPc = _reboot.Count > 0;
    }

    /// <summary>"Restart and apply": the waiting changes in one Run (after the session's restore point): their
    /// Prepares now, then a Run in phases restarts into Safe Mode for them and back (Engine.SafeMode).</summary>
    [RelayCommand]
    public async Task SafeRunAsync()
    {
        if (Running || SafePending.Count == 0) return;
        var n = SafePending.Count;
        if (!await _dialogs.ConfirmAsync("Safe Mode",
                $"AkariOS restarts into Safe Mode now to apply {n} change{(n != 1 ? "s" : "")}, then back to normal. Save your work first.",
                "Restart now", "Cancel")) return;
        StartSafeRun();
    }

    private void StartSafeRun()
    {
        var n = SafePending.Count;
        var plan = SafePending.Select(kv => new PlanItem(kv.Key, kv.Value.Mode, kv.Value.Value)).ToList();
        Enqueue($"Applying {n} change{(n != 1 ? "s" : "")} in Safe Mode", restore: true, () => { },
            () => _engine.Runner.Run(plan, _engine.Find, new PostedProgress(_background, p => { if (_busy is { } b) _shell.Report(b, p); })),
            r =>
            {
                SafePending.Clear();
                // a Prepare that failed (a download) left its change out of Safe Mode: its card says why
                foreach (var o in r as IReadOnlyList<Outcome> ?? [])
                    if (o.Kind == OutcomeKind.Failed && _engine.Find(o.Id) is { } t) Card(t).Error = o.Message;
                foreach (var t in plan.Select(i => _engine.Find(i.Id)).OfType<Tweak>()) Show(Card(t));
            });
    }

    [RelayCommand]
    public void RestartExplorer()
    {
        // a Run or the ISO Builder working: Explorer restarts with it later (the bar stays)
        if (Running || _shell.Locked) return;
        Running = true;
        _busy = _shell.Begin("Restarting Explorer");
        _background.Run(() => { _engine.Explorer.Restart(); return null; }, _ =>
        {
            Running = false;
            _shell.End(_busy);
            _explorer.Clear();
            UpdateBars();
            _ = Guard(NextAsync());
        });
    }

    [RelayCommand]
    public async Task RestartPcAsync()
    {
        if (Running || _engine.Shutdown is not { } shutdown) return;
        if (_shell.Locked)
        {
            await _dialogs.ShowInfoAsync("Restart", $"{_shell.Work.LastOrDefault()?.Label ?? "A Run"} is still running. Restart when it is done.");
            return;
        }
        if (!await _dialogs.ConfirmAsync("Restart", "Restart the PC now? Save your work first.", "Restart now", "Cancel")) return;
        Running = true;
        _busy = _shell.Begin("Restarting the PC");
        _background.Run(() => { shutdown.Restart(); return null; }, _ => { Running = false; _shell.End(_busy); });
    }

    // ---- closing

    /// <summary>Whether closing the window has to ask (<see cref="CanCloseAsync"/>) first.</summary>
    public bool MustAsk => Running || SafePending.Count > 0;

    /// <summary>The window is closing: a change still running asks first; Safe Mode changes waiting ask to be applied
    /// (one Run in phases: the PC restarts) or discarded. False keeps the window open.</summary>
    public async Task<bool> CanCloseAsync()
    {
        if (Running && !await _dialogs.ConfirmAsync("AkariOS", "A change is still running. Close AkariOS anyway? It may be left half done.", "Close anyway", "Wait"))
            return false;
        if (Running || SafePending.Count == 0) return true;
        var n = SafePending.Count;
        var r = await _dialogs.ShowAsync("AkariOS",
            $"{n} change{(n != 1 ? "s are" : " is")} waiting for Safe Mode. Restart and apply {(n != 1 ? "them" : "it")} now, or discard {(n != 1 ? "them" : "it")}?",
            "Restart and apply", "Discard");
        if (r != ContentDialogResult.Primary) return true;
        await SafeRunAsync();
        return false;
    }
}
