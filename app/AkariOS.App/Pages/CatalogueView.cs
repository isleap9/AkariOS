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
    private readonly Queue<(CatalogueCard Card, TweakMode Mode, object? Value)> _queue = new();
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
        s.Shell.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(ShellViewModel.Page)) UpdateBars(); };
    }

    /// <summary>The Tweaks it lists (this PC's).</summary>
    public IReadOnlyList<Tweak> Tweaks => _tweaks ??= Catalogue.Tweaks(s.Engine.Loaded.Tweaks, s.Engine.System);

    /// <summary>Safe Mode changes waiting for "Restart and apply" (N7 runs them).</summary>
    public Dictionary<string, SafeChange> SafePending { get; } = [];

    /// <summary>A change runs now (one at a time, Explorer's and the PC's restart included).</summary>
    public bool Running { get; private set; }

    public CatalogueBars Bars => _bars;

    /// <summary>A card, made the first time.</summary>
    public CatalogueCard Card(Tweak t) =>
        _cards.TryGetValue(t.Id, out var c) ? c : _cards[t.Id] = CatalogueCard.Make(t, s.Engine.States.DefaultFor(t), (card, mode, value) => Change(card.Tweak, mode, value));

    /// <summary>Show-AkariCataloguePage: a page (key) or, with a query, the search's results across the Catalogue.
    /// The Services and Scheduled tasks pages keep their Tweaks while the search waits for their lists (N6).</summary>
    public UIElement Build(string page, string query)
    {
        var lists = Catalogue.Lists.ContainsKey(page);
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
        if (lists)
        {
            var note = Parts.Text($"The list of {(page.EndsWith("Services", StringComparison.Ordinal) ? "services" : "scheduled tasks")} on this PC comes with N6 (docs/plans/2026-10-31-native-app.md). The PowerShell app has it today.", 13, "Mu");
            note.Margin = new Thickness(2, 12, 0, 0);
            panel.Children.Add(note);
        }

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
        _queue.Enqueue((c, mode, value));
        Next();
    }

    private sealed record ChangeDone(Outcome? Outcome, StateRead Read);

    // Start-AkariCatalogueNext: the Runner, then the State read back; the session's first change gets an AkariOS
    // restore point first (not a Check / Open button), and goes on without one when Windows refuses
    private void Next()
    {
        if (Running || !_queue.TryDequeue(out var it)) return;
        var (c, mode, value) = it;
        var t = c.Tweak;
        Running = true;
        c.Busy = CatalogueBusy.Running;
        Show(c);
        var restore = !(t.Kind == TweakKind.Action && t.Button is "Check" or "Open") && s.RestoreChoice("Optimize");
        if (restore) s.RestoreDone = true;
        var verb = t.Kind == TweakKind.Action ? t.Button.ToLowerInvariant() : mode == TweakMode.Apply ? "apply" : "revert";
        var label = $"{t.Name}: {verb}";
        s.Shell.SetBusy(true, label, locked: false);
        s.Log.Write(label);
        s.Background(() =>
        {
            if (restore && s.Engine.RestorePoints?.Create("AkariOS") is { Ok: false })
                s.Log.Write("Warning: going on without a restore point");
            Outcome? o = null;
            try { o = s.Engine.Runner.Run(t, mode, value); }
            catch (Exception e) { s.Log.WriteFile($"Error: {t.Id}: {e}"); }
            return new ChangeDone(o, Read(t));
        }, r =>
        {
            Running = false;
            s.Shell.SetBusy(false);
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
            // Home's "changes applied" is read again
            s.AppliedCount = null;
            Show(c);
            UpdateBars();
            Next();
        });
    }

    // ---- the bars

    private void UpdateBars() =>
        _bars.Update(s.Bars, Catalogue.Split(s.Shell.Page) is not null, SafePending.Count,
            Catalogue.RestartBarText(_explorer.Count, _reboot.Count), _explorer.Count > 0, _reboot.Count > 0);

    private void SafeRun() => s.NotYet("Restart and apply (changes that run in Safe Mode)", "N7");

    private void RestartExplorer()
    {
        if (Running) return;
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
        if (Running) return;
        if (s.Engine.Shutdown is not { } shutdown) { s.NotYet("Restarting the PC from here", "N7"); return; }
        if (s.Dialogs?.Confirm("Restart the PC now? Save your work first.", "Restart now", "Cancel", "Warning", "Restart") != true) return;
        Running = true;
        s.Shell.SetBusy(true, "Restarting the PC", locked: false);
        s.Background(() => { shutdown.Restart(); return null; }, _ => { Running = false; s.Shell.SetBusy(false); });
    }

    // ---- closing

    /// <summary>The window is closing: a change still running asks first; Safe Mode changes waiting ask to be applied
    /// (one restart, N7) or discarded. False keeps the window open.</summary>
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
