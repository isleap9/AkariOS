using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using System.IO;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>The window's step footer (Back, the stepper, Next), pinned under the page.</summary>
public sealed record StepFooter(Border Bar, Button Back, Panel Dots, Button Next);

/// <summary>
/// The Install AkariOS page (src/UI/Steps.ps1): a chooser (One-click comes with N7, or Guided), then Guided's steps
/// Apps (N5) → Tweaks → Review &amp; Apply → the result, with the stepper in the footer and the step in the page header.
/// Nothing changes while choosing: the rows write into <see cref="Selection"/>; Apply runs it once, in the background,
/// after the session's restore point. One per run: its state stays when another page is shown.
/// </summary>
public sealed class InstallPage
{
    /// <summary>The step names, and each step's page header (the last one is the result screen).</summary>
    public static IReadOnlyList<string> StepNames { get; } = ["Apps", "Tweaks", "Review & Apply"];

    public static IReadOnlyList<(string Title, string Sub)> StepHeaders { get; } =
    [
        ("Apps", "Pick the apps to remove and the apps to install"),
        ("Tweaks", "Pick what to change. Hover a row for details."),
        ("Review & Apply", "These changes run in one go, after an AkariOS restore point"),
        ("Done", "What happened to each change"),
    ];

    private readonly AppServices s;
    private readonly Border _root = new();
    private string _query = "";
    private string _motionKey = "";

    public InstallPage(AppServices services)
    {
        s = services;
        Tweaks = NewTweaks();
        s.Shell.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(ShellViewModel.Page)) UpdateFooter(); };
    }

    /// <summary>Choose (One-click or Guided) or Guided (the steps).</summary>
    public string Mode { get; private set; } = "Choose";

    /// <summary>Guided's step: 0 Apps, 1 Tweaks, 2 Review &amp; Apply, 3 the result.</summary>
    public int Step { get; private set; }

    /// <summary>The pending changes, by Tweak id, in Review's order.</summary>
    public OrderedDictionary<string, Pending> Selection { get; } = [];

    public TweaksStep Tweaks { get; private set; }

    /// <summary>A Run is applying the Selection now.</summary>
    public bool Running { get; private set; }

    /// <summary>The last Run's Outcomes (the result screen).</summary>
    public IReadOnlyList<Core.Runs.Outcome> Outcomes { get; private set; } = [];

    private TweaksStep NewTweaks() => new(s, Selection, UpdateFooter);

    /// <summary>The page (the same element each time), on the current step; the search filters the Tweaks step.</summary>
    public UIElement Build(string query)
    {
        _query = query;
        Show();
        return _root;
    }

    /// <summary>Guided's first step (Home's "Choose changes").</summary>
    public void Guide() => Go("Guided", 0);

    private void Go(string mode, int step)
    {
        (Mode, Step) = (mode, step);
        Show();
    }

    private void Back()
    {
        if (Mode == "Choose") { s.Shell.Open("Home"); return; }
        if (Step > 0) Go(Mode, Step - 1); else Go("Choose", 0);
    }

    private void Forward()
    {
        switch (Step)
        {
            case 2: Apply(); break;
            case 3: Reset(); s.Shell.Open("Home"); break;
            default: Go(Mode, Step + 1); break;
        }
    }

    // Show-AkariSteps: the step in the header and the stepper, its body sliding in from the side it comes from
    private void Show()
    {
        UIElement body;
        if (Mode == "Choose")
        {
            s.Shell.SetHeader("Install AkariOS", "Optimize Windows in one click, or pick each change yourself");
            body = Chooser();
        }
        else
        {
            var (title, sub) = StepHeaders[Step];
            s.Shell.SetHeader(title, sub);
            body = Step switch
            {
                0 => Note("Removing and installing apps comes with N5 (docs/plans/2026-10-31-native-app.md). The PowerShell app has it today. Go on to the Tweaks."),
                1 => Tweaks.View(_query),
                2 => ReviewStep.Review(Selection.Values, s.Engine.Find),
                _ => ReviewStep.Result(Outcomes, s.Engine.Find),
            };
        }
        if (_root.Child != body)
        {
            // the cached Tweaks view leaves its old place first
            _root.Child = null;
            _root.Child = body;
        }
        var key = $"{Mode}|{Step}";
        if (key != _motionKey)
        {
            var old = _motionKey.Split('|');
            _motionKey = key;
            var dir = old.Length == 2 && old[0] == Mode ? Math.Sign(Step - int.Parse(old[1], System.Globalization.CultureInfo.InvariantCulture)) : 0;
            if (dir != 0) Motion.Entrance(body, MotionKind.Slide, 32 * dir);
            else Motion.Entrance(body, MotionKind.Fade, speed: "Base");
        }
        UpdateFooter();
    }

    // ---- Apply: one Run in the background, the restore point first

    /// <summary>Start-AkariApply: the Selection as one Run (the Runner: Explorer restarted once, changes that restart
    /// the PC last), after the session's restore point; Windows refusing it asks whether to go on without one.</summary>
    public void Apply(bool skipRestore = false)
    {
        if (Running || Selection.Count == 0) return;
        if (s.Catalogue is { Running: true }) { s.Dialogs?.Message("A change from Optimize is still running. Apply these when it is done."); return; }
        var plan = Core.Tweaks.Selection.PlanItems(Selection.Values);
        var restore = !skipRestore && s.RestoreChoice(Mode);
        var label = $"Applying {plan.Count} change{(plan.Count == 1 ? "" : "s")}";
        Running = true;
        s.Shell.SetBusy(true, label);
        s.Log.Write(label);
        UpdateFooter();
        var progress = new Posted(s, p => s.Shell.SetProgress(p.Done, p.Total, p.Step));
        s.Background(() =>
        {
            if (restore && s.Engine.RestorePoints?.Create("AkariOS") is { Ok: false } refused) return refused;
            return s.Engine.Runner.Run(plan, s.Engine.Find, progress);
        }, r => Applied(r, plan, restore));
    }

    private void Applied(object? r, IReadOnlyList<Core.Runs.PlanItem> plan, bool restore)
    {
        Running = false;
        s.Shell.SetBusy(false);
        if (r is Core.Runs.RestoreResult refused)
        {
            // stopped before any change: ask, then go on without one (Cancel: the next Apply tries again)
            UpdateFooter();
            if (s.Dialogs?.Confirm($"Akari could not create a restore point:\n\n{refused.Message}\n\nApply the changes without a restore point?", "Apply anyway", "Cancel", "Warning", "Restore point") == true)
            {
                s.RestoreDone = true;
                Apply(skipRestore: true);
            }
            return;
        }
        if (restore) s.RestoreDone = true;
        if (r is not IReadOnlyList<Core.Runs.Outcome> outcomes)
        {
            s.Dialogs?.Message("The changes stopped before they ran. The details are in akari.log.", "Error");
            UpdateFooter();
            return;
        }
        Outcomes = outcomes;
        // Last used (Quick select): what the Guided Run was asked to do
        try { s.Engine.Presets.SaveLastUsed(plan); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { s.Log.Write($"Warning: Last used not saved ({e.Message})"); }
        // what this PC has now: Home's count and the Catalogue's cards are read again
        s.AppliedCount = null;
        s.Catalogue?.Stale();
        Go(Mode, 3);
    }

    /// <summary>Done (Reset-AkariSteps): the Selection forgotten, the chooser next time, every State read again.</summary>
    public void Reset()
    {
        Selection.Clear();
        Outcomes = [];
        Tweaks = NewTweaks();
        (Mode, Step) = ("Choose", 0);
        _root.Child = null;
    }

    /// <summary>The window is closing: a Run still applying asks first.</summary>
    public bool CanClose() =>
        !Running || s.Dialogs?.Confirm("Changes are still being applied. Close AkariOS anyway? They may be left half done.", "Close anyway", "Wait", "Warning") == true;

    // a Run's progress, handed to the UI thread
    private sealed class Posted(AppServices s, Action<Core.Runs.RunProgress> show) : IProgress<Core.Runs.RunProgress>
    {
        public void Report(Core.Runs.RunProgress value) => s.Post(() => show(value));
    }

    private UIElement Chooser()
    {
        var g = new UniformGrid { Columns = 2 };
        var one = Parts.ModeCard("zap", "One-click", "The full AkariOS setup in one go: apps, drivers, Safe Mode and tweaks, with restarts handled for you. For a fresh install.", hot: true);
        one.Margin = new Thickness(0, 0, 8, 0);
        one.Click += (_, _) => s.NotYet("One-click", "N7");
        var guided = Parts.ModeCard("list-checks", "Guided", "Pick the apps to remove and the Tweaks to apply, review the changes, then apply them in one go.");
        guided.Margin = new Thickness(8, 0, 0, 0);
        guided.Click += (_, _) => Guide();
        g.Children.Add(one);
        g.Children.Add(guided);
        return g;
    }

    private static TextBlock Note(string text) => Parts.Text(text, 14, "Mu");

    // Update-AkariStepFooter: Back always; Next, Review (n) or Apply by step; the stepper; only on this page
    private void UpdateFooter()
    {
        if (s.Footer is not { } f) return;
        var here = s.Shell.Page == "Install AkariOS";
        f.Bar.Visibility = here ? Visibility.Visible : Visibility.Collapsed;
        if (!here) return;
        f.Dots.Children.Clear();
        f.Back.Visibility = Visibility.Visible;
        f.Back.IsEnabled = !Running;
        if (Mode == "Choose") { f.Next.Visibility = Visibility.Collapsed; return; }
        f.Next.Visibility = Visibility.Visible;
        var n = Selection.Count;
        (f.Next.Content, f.Next.IsEnabled) = Step switch
        {
            0 => ("Next", true),
            1 => ($"Review ({n})", n > 0),
            2 => ("Apply", n > 0 && !Running),
            _ => ((object)"Done", true),
        };
        if (Step == 3) f.Back.Visibility = Visibility.Hidden;
        var cur = Math.Min(Step, 2);
        for (var i = 0; i < StepNames.Count; i++)
            f.Dots.Children.Add(StepItem(i + 1, StepNames[i], i < cur || Step > 2 ? "Done" : i == cur ? "Current" : "", i > 0));
    }

    /// <summary>Hooks the footer's buttons (once, when the window is up).</summary>
    public void Attach(StepFooter f)
    {
        f.Back.Click += (_, _) => { if (s.Shell.Page == "Install AkariOS") Back(); };
        f.Next.Click += (_, _) => { if (s.Shell.Page == "Install AkariOS") Forward(); };
        UpdateFooter();
    }

    // New-AkariStepItem: a short line from the step before, the numbered circle (a check when done), the name
    private static StackPanel StepItem(int number, string name, string state, bool line)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal, Tag = state };
        if (line)
        {
            var l = new Border { Width = 28, Height = 1.5, Margin = new Thickness(12, 0, 12, 0), VerticalAlignment = VerticalAlignment.Center };
            l.SetResourceReference(Border.BackgroundProperty, state.Length > 0 ? "Acc" : "CtlBd");
            sp.Children.Add(l);
        }
        var c = new Border { Tag = state, VerticalAlignment = VerticalAlignment.Center };
        c.SetResourceReference(FrameworkElement.StyleProperty, "StepNum");
        if (state == "Done")
        {
            var ic = Icons.Make("check", 14, "AccText");
            ic.HorizontalAlignment = HorizontalAlignment.Center;
            ic.VerticalAlignment = VerticalAlignment.Center;
            c.Child = ic;
        }
        else
        {
            var t = new TextBlock { Text = $"{number}", FontSize = 12, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            t.SetResourceReference(TextBlock.FontFamilyProperty, "FontDisplay");
            c.Child = t;
        }
        sp.Children.Add(c);
        var lb = Parts.Text(name, 13, state == "Current" ? "Tx" : "Mu");
        lb.TextWrapping = TextWrapping.NoWrap;
        lb.VerticalAlignment = VerticalAlignment.Center;
        lb.Margin = new Thickness(8, 0, 0, 1);
        if (state == "Current") lb.FontWeight = FontWeights.SemiBold;
        sp.Children.Add(lb);
        return sp;
    }
}
