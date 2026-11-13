using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>
/// Optimize › Advanced, the Catalogue's page (src/UI/CataloguePage.ps1): a Category page or the search results, its
/// cards (kept per Tweak), a Refresh button, the States read in the background one by one. A change acts right away:
/// confirmed when needed, then queued and run one at a time, the session's restore point first; a Safe Mode Tweak
/// outside Safe Mode waits in the Safe Mode bar instead; Explorer and PC restarts collect in the restart bar.
/// </summary>
public sealed class CatalogueView
{
    private readonly AppServices s;
    private readonly Dictionary<string, CatalogueCard> _cards = [];
    private readonly Queue<Job> _queue = new();
    private readonly HashSet<string> _explorer = [];
    private readonly HashSet<string> _reboot = [];
    private readonly CatalogueBars _bars;
    private IReadOnlyList<Tweak>? _tweaks;
    private Panel? _shown;
    private string _shownKey = "";
    private string _movedKey = "";

    public CatalogueView(AppServices services)
    {
        s = services;
        _bars = new CatalogueBars(SafeRun, RestartExplorer, RestartPc);
        Services = new ServicesList(s, this);
        Tasks = new TasksList(s, this);
        s.Shell.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(ShellViewModel.Page)) UpdateBars(); };
    }

    /// <summary>The Services page's list (Show-AkariServiceList), under its Category's Tweaks.</summary>
    public ServicesList Services { get; }

    /// <summary>The Scheduled tasks page's list (Show-AkariTaskList).</summary>
    public TasksList Tasks { get; }

    /// <summary>The Tweaks it lists (this PC's).</summary>
    public IReadOnlyList<Tweak> Tweaks => _tweaks ??= Catalogue.Tweaks(s.Engine.Loaded.Tweaks, s.Engine.System);

    /// <summary>Safe Mode changes waiting for "Restart and apply" (one Run in phases).</summary>
    public Dictionary<string, SafeChange> SafePending { get; } = [];

    /// <summary>A change runs now (one at a time, Explorer's and the PC's restart included).</summary>
    public bool Running { get; private set; }

    public CatalogueBars Bars => _bars;

    /// <summary>A card, made the first time.</summary>
    public CatalogueCard Card(Tweak t) =>
        _cards.TryGetValue(t.Id, out var c) ? c : _cards[t.Id] = CatalogueCard.Make(t, s.Engine.States.DefaultFor(t), (card, mode, value) => Change(card.Tweak, mode, value));

    /// <summary>Show-AkariCataloguePage: a page (key) or, with a query, the search's results across the Catalogue.
    /// The Services and Scheduled tasks pages keep their Tweaks; the search filters their list.</summary>
    public UIElement Build(string page, string query)
    {
        var lists = Catalogue.Lists.ContainsKey(page);
        var listQuery = query;
        if (lists) query = "";
        var list = Catalogue.List(Tweaks, page, query);
        // the cards are kept: take them off the page shown before
        _shown?.Children.Clear();
        var panel = new StackPanel();
        _shown = panel;

        var bar = new DockPanel { Margin = new Thickness(0, 0, 0, 12) };
        var refresh = Parts.Button("Refresh", click: () => ReadStates(Catalogue.List(Tweaks, page, query)));
        refresh.Margin = new Thickness(0);
        refresh.ToolTip = "Read the current state of these tweaks again";
        DockPanel.SetDock(refresh, Dock.Right);
        bar.Children.Add(refresh);
        var count = Parts.Text($"{list.Count} tweak{(list.Count == 1 ? "" : "s")}", 13, "Mu");
        count.VerticalAlignment = VerticalAlignment.Center;
        bar.Children.Add(count);
        panel.Children.Add(bar);

        var last = "";
        foreach (var t in list)
        {
            // search results: a heading per Section › Category
            var key = Catalogue.Key(t.Section, t.Category);
            if (query.Length > 0 && key != last)
            {
                last = key;
                var h = Parts.Title($"{Catalogue.HeaderOf(t.Section)} › {t.Category}", 14);
                h.Margin = new Thickness(2, 12, 0, 6);
                panel.Children.Add(h);
            }
            var c = Card(t);
            panel.Children.Add(c.Card);
            Show(c);
        }
        if (list.Count == 0) panel.Children.Add(Parts.Text(query.Length > 0 ? "No tweak matches." : "Nothing here yet.", 13, "Mu"));
        if (lists) panel.Children.Add(page.EndsWith("Services", StringComparison.Ordinal) ? Services.View(listQuery) : Tasks.View(listQuery));

        // the same page and search again (Show-Page's rebuild) reads nothing; another page, or the search starting or
        // ending, staggers its cards in
        var shown = $"{page}|{query}";
        var moved = $"{page}|{query.Length > 0}";
        if (shown != _shownKey) ReadStates(list);
        if (moved != _movedKey) Motion.Stagger(panel.Children.OfType<UIElement>());
        (_shownKey, _movedKey) = (shown, moved);
        UpdateBars();
        return panel;
    }

    /// <summary>The PC changed outside this page (a Guided Run): the next page shown reads its States again.</summary>
    public void Stale() => _shownKey = "";

    private void Show(CatalogueCard c) => c.Update(SafePending.GetValueOrDefault(c.Tweak.Id));

    // ---- States, read in the background

    /// <summary>Start-AkariCatalogueStates: the Toggles' and Choices' States, read off the UI thread one after another
    /// (a card says "Reading…" until its own arrives); cards busy with a change are left alone.</summary>
    public void ReadStates(IEnumerable<Tweak> tweaks)
    {
        var queue = new Queue<CatalogueCard>();
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

    private void ReadNext(Queue<CatalogueCard> queue)
    {
        if (!queue.TryDequeue(out var c)) return;
        s.Background(() => Read(c.Tweak), r =>
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
        try { state = s.Engine.States.Of(t); } catch (Exception) { }
        object? current = null;
        if (t.Kind == TweakKind.Choice) try { current = s.Engine.States.ChoiceValue(t); } catch (Exception) { }
        return new StateRead(state, current);
    }

    // ---- changes: right away, one at a time

    /// <summary>A card's control was used (Invoke-AkariCatalogueChange): asks first when the change needs it, then
    /// queues it; a Safe Mode Tweak outside Safe Mode waits in the Safe Mode bar instead. Value: a Choice value other
    /// than Recommended.</summary>
    public void Change(Tweak t, TweakMode mode, object? value = null)
    {
        var c = Card(t);
        if (IsoBusy()) { Show(c); return; }
        if (c.Busy != CatalogueBusy.None || c.NotNative is not null) { Show(c); return; }
        if (mode == TweakMode.Apply)
        {
            var target = t.Kind == TweakKind.Choice ? value ?? t.Recommended : Selection.Optimized;
            if (Selection.ConfirmText(t, target, c.WindowsDefault) is { } q && s.Dialogs?.Confirm(q, "Continue") != true) { Show(c); return; }
        }
        c.Error = "";
        if (t.SafeMode && !s.Engine.InSafeMode())
        {
            Catalogue.SetSafePending(SafePending, t, c.State, mode, value, c.Current);
            Show(c);
            UpdateBars();
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
                try { o = s.Engine.Runner.Run(t, mode, value); }
                catch (Exception e) { s.Log.WriteFile($"Error: {t.Id}: {e}"); }
                return new ChangeDone(o, Read(t));
            },
            r => Changed(c, r));
    }

    private sealed record ChangeDone(Outcome? Outcome, StateRead Read);

    /// <summary>A change in the queue: its status bar label, whether it gets the session's restore point first, what
    /// to show when it starts, the work (off the UI thread) and what to show with its result.</summary>
    private sealed record Job(string Label, bool Restore, Action Begin, Func<object?> Work, Action<object?> Done);

    /// <summary>An ISO Builder job runs: changes are refused meanwhile, saying so (the caller leaves its row as it
    /// was).</summary>
    public bool IsoBusy()
    {
        if (s.Iso?.Running != true) return false;
        s.Dialogs?.Message("The ISO Builder is still working. Make this change when it is done.", "Info", Pages.IsoPage.Title);
        return true;
    }

    /// <summary>Queues a change (a Tweak's, a service's, a task's): run one at a time, after the ones before it.</summary>
    public void Enqueue(string label, bool restore, Action begin, Func<object?> work, Action<object?> done)
    {
        _queue.Enqueue(new Job(label, restore, begin, work, done));
        Next();
    }

    // Start-AkariCatalogueNext: the next change; the session's first one gets an AkariOS restore point first (not a
    // Check / Open button), and goes on without one when Windows refuses
    private void Next()
    {
        if (Running || !_queue.TryDequeue(out var job)) return;
        Running = true;
        job.Begin();
        var restore = job.Restore && s.RestoreChoice("Optimize");
        if (restore) s.RestoreDone = true;
        s.Shell.SetBusy(true, job.Label, locked: false);
        s.Log.Write(job.Label);
        s.Background(() =>
        {
            if (restore && s.Engine.RestorePoints?.Create("AkariOS") is { Ok: false })
                s.Log.Write("Warning: going on without a restore point");
            return job.Work();
        }, r =>
        {
            Running = false;
            s.Shell.SetBusy(false);
            job.Done(r);
            // Home's "changes applied" is read again
            s.AppliedCount = null;
            UpdateBars();
            Next();
        });
    }

    // a Tweak's change is done: the card shows its State read back, a failure, the restarts it needs
    private void Changed(CatalogueCard c, object? r)
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
                if (t.Explorer) _explorer.Add(t.Id);
                if (t.Reboot) _reboot.Add(t.Id);
            }
        }
        else c.Error = "it stopped before its change (see the log)";
        Show(c);
    }

    // ---- the bars

    private void UpdateBars() =>
        _bars.Update(s.Bars, Catalogue.Split(s.Shell.Page) is not null, SafePending.Count,
            Catalogue.RestartBarText(_explorer.Count, _reboot.Count), _explorer.Count > 0, _reboot.Count > 0);

    // Start-AkariCatalogueSafeRun: the waiting changes in one Run (after the session's restore point): their Prepares
    // now, then a Run in phases restarts into Safe Mode for them and back (Engine.SafeMode)
    private void SafeRun()
    {
        if (Running || SafePending.Count == 0 || IsoBusy()) return;
        var n = SafePending.Count;
        if (s.Dialogs?.Confirm($"AkariOS restarts into Safe Mode now to apply {n} change{(n != 1 ? "s" : "")}, then back to normal. Save your work first.",
                "Restart now", "Cancel", "Warning", "Safe Mode") != true) return;
        var plan = SafePending.Select(kv => new PlanItem(kv.Key, kv.Value.Mode, kv.Value.Value)).ToList();
        var label = $"Applying {n} change{(n != 1 ? "s" : "")} in Safe Mode";
        Enqueue(label, restore: true, () => { },
            () => s.Engine.Runner.Run(plan, s.Engine.Find),
            r =>
            {
                SafePending.Clear();
                // a Prepare that failed (a download) left its change out of Safe Mode: its card says why
                foreach (var o in r as IReadOnlyList<Outcome> ?? [])
                    if (o.Kind == OutcomeKind.Failed && s.Engine.Find(o.Id) is { } t) Card(t).Error = o.Message;
                foreach (var c in plan.Select(i => s.Engine.Find(i.Id)).OfType<Tweak>()) Show(Card(c));
            });
    }

    private void RestartExplorer()
    {
        if (Running || IsoBusy()) return;
        Running = true;
        s.Shell.SetBusy(true, "Restarting Explorer", locked: false);
        s.Background(() => { s.Engine.Explorer.Restart(); return null; }, _ =>
        {
            Running = false;
            s.Shell.SetBusy(false);
            _explorer.Clear();
            UpdateBars();
            Next();
        });
    }

    private void RestartPc()
    {
        if (Running || IsoBusy()) return;
        if (s.Engine.Shutdown is not { } shutdown) return;
        if (s.Dialogs?.Confirm("Restart the PC now? Save your work first.", "Restart now", "Cancel", "Warning", "Restart") != true) return;
        Running = true;
        s.Shell.SetBusy(true, "Restarting the PC", locked: false);
        s.Background(() => { shutdown.Restart(); return null; }, _ => { Running = false; s.Shell.SetBusy(false); });
    }

    // ---- closing

    /// <summary>The window is closing: a change still running asks first; Safe Mode changes waiting ask to be applied
    /// (one Run in phases: the PC restarts) or discarded. False keeps the window open.</summary>
    public bool CanClose()
    {
        if (Running && s.Dialogs?.Confirm("A change is still running. Close AkariOS anyway? It may be left half done.", "Close anyway", "Wait", "Warning") != true)
            return false;
        if (Running || SafePending.Count == 0) return true;
        var n = SafePending.Count;
        var r = s.Dialogs?.Show($"{n} change{(n != 1 ? "s are" : " is")} waiting for Safe Mode. Restart and apply {(n != 1 ? "them" : "it")} now, or discard {(n != 1 ? "them" : "it")}?",
            "AkariOS", ["Discard", "Restart and apply"], "Question");
        if (r != "Restart and apply") return true;
        SafeRun();
        return false;
    }

    /// <summary>For the window: closing asks <see cref="CanClose"/>.</summary>
    public void OnClosing(object? sender, CancelEventArgs e) { if (!CanClose()) e.Cancel = true; }
}
