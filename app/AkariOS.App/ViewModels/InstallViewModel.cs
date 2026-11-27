using System.Collections.ObjectModel;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Presets;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.ViewModels;

/// <summary>A step of the stepper: its number, name, and Done / Current / "" (to come).</summary>
public sealed record StepItem(int Number, string Name, string State)
{
    public bool IsDone => State == "Done";
    public bool IsCurrent => State == "Current";
    public bool HasLine => Number > 1;
    public bool IsToCome => State == "";
    public double TextOpacity => IsToCome ? 0.6 : 1;
    public string NumberText => $"{Number}";
}

/// <summary>A Review row (New-AkariReviewRow): the Tweak's glyph, its name, the change; a heading row for the changes
/// to Tweaks only Optimize shows.</summary>
public sealed record ReviewRow(string Id, string Name, string Line, string Glyph, bool IsHeading = false)
{
    public bool IsRow => !IsHeading;
}

/// <summary>A Review group (Remove, Install, Tweaks): its glyph, title, the count line, rows.</summary>
public sealed record ReviewGroup(string Glyph, string Title, string Detail, IReadOnlyList<ReviewRow> Rows, bool Open)
{
    public bool IsEmpty => Rows.Count == 0;
}

/// <summary>One phase of One-click as the chooser explains it.</summary>
public sealed record PhaseItem(int Number, string Name, string Text)
{
    public string NumberText => $"{Number}";
}

public enum RunState { Waiting, Working, Applied, Failed, Skipped, Already }

/// <summary>A row of the run page (New-AkariRunItems): Waiting → Working → Applied / Failed / Skipped / Already.</summary>
public sealed partial class RunItemViewModel(string id, string name, string plain, string kind, string glyph) : ObservableObject
{
    public string Id { get; } = id;
    public string Name { get; } = name;

    /// <summary>The Tweak's own name (the Runner's progress names it).</summary>
    public string Plain { get; } = plain;
    public string Kind { get; } = kind;
    public string Glyph { get; } = glyph;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(StateText), nameof(IsWorking), nameof(IsOk), nameof(IsBad), nameof(IsPlain))]
    public partial RunState State { get; set; }

    public string StateText => State == RunState.Working ? "Working" : State.ToString();
    public bool IsWorking => State == RunState.Working;
    public bool IsOk => State == RunState.Applied;
    public bool IsBad => State == RunState.Failed;
    public bool IsPlain => State is RunState.Waiting or RunState.Skipped or RunState.Already;
}

/// <summary>A result card (Show-AkariResult): the change's name and why it failed or was skipped.</summary>
public sealed record ResultItem(string Name, string Why);

/// <summary>
/// Install AkariOS (src/UI/Steps.ps1; the WPF app's InstallPage): a chooser (One-click, Guided), then Guided's steps
/// Apps → Tweaks → Review &amp; Apply, the run page while the Run applies, then the result. Nothing changes while choosing:
/// the steps write into <see cref="Selection"/>; Apply runs it once, in the background, after the session's restore
/// point. One per app: its state stays while other pages show.
/// </summary>
public sealed partial class InstallViewModel : ObservableObject
{
    /// <summary>$AkariStepNames.</summary>
    public static IReadOnlyList<string> StepNames { get; } = ["Apps", "Tweaks", "Review & Apply"];

    /// <summary>$AkariOneClickPhases.</summary>
    public static IReadOnlyList<PhaseItem> Phases { get; } =
    [
        new(1, "Prepare", "Allows scripts, makes a restore point, gets the graphics driver cleanup ready"),
        new(2, "Drivers", "Restarts into Safe Mode and removes graphics drivers with Display Driver Uninstaller"),
        new(3, "Safe Mode", "Applies the security changes that only work in Safe Mode, then restarts back"),
        new(4, "Debloat and tweaks", "Removes Store apps and features, applies every AkariOS Tweak, installs your apps"),
        new(5, "Finish", "Rebuilds performance counters, applies the final registry set, restarts one last time"),
    ];

    /// <summary>Confirm-AkariOneClick.</summary>
    public const string OneClickWarning = "AkariOS changes a lot of Windows, including security features.\n\n" +
        "- Run it on a fresh install or a PC you can reinstall. Undo (Settings › Recovery) puts settings back; removed apps and drivers stay removed.\n" +
        "- Security is reduced on purpose (Defender settings, UAC, memory integrity).\n" +
        "- Your PC restarts several times, once into Safe Mode. Save your work and don't interrupt it.\n" +
        "- Graphics and audio drivers are removed. Install a fresh graphics driver afterwards.\n" +
        "- It is tuned for desktops: power saving is turned off.\n" +
        "- It needs an internet connection.";

    /// <summary>Added to the warning on a laptop: the Ultimate Performance plan is left out.</summary>
    public const string LaptopNote = "\n\nThis PC is a laptop: the Ultimate Performance power plan is left out, so your power plan and battery life stay as they are.";

    /// <summary>The browser question's "none" option.</summary>
    public const string NoBrowser = "No browser";

    private readonly Engine _engine;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly ITextDialog _text;
    private readonly ShellState _shell;
    private readonly RestoreRule _restore;
    private readonly CatalogueViewModel _catalogue;
    private readonly HomeStats _stats;
    private readonly ActivityLog _activity;
    private readonly IShellNavigator _navigator;
    private readonly IShellOpen _open;
    private readonly IFilePicker _picker;
    private readonly OneClickHandoff _oneClick;
    private readonly IChoiceDialog _choice;
    private readonly AppIcons _icons;

    public InstallViewModel(Engine engine, IBackground background, IDialogService dialogs, ITextDialog text, ShellState shell, RestoreRule restore,
        CatalogueViewModel catalogue, HomeStats stats, ActivityLog activity, IShellNavigator navigator, IShellOpen open, IFilePicker picker, OneClickHandoff oneClick, IChoiceDialog choice, AppIcons icons)
    {
        (_icons, _choice) = (icons, choice);
        (_engine, _background, _dialogs, _text, _shell, _restore) = (engine, background, dialogs, text, shell, restore);
        (_catalogue, _stats, _activity, _navigator, _open, _picker, _oneClick) = (catalogue, stats, activity, navigator, open, picker, oneClick);
        (Tweaks, Apps) = (NewTweaks(), NewApps());
        Update();
    }

    /// <summary>The pending changes, by Tweak id, in Review's order.</summary>
    public OrderedDictionary<string, Pending> Selection { get; } = [];

    /// <summary>Choose (One-click or Guided) or Guided.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsChoosing), nameof(IsGuided), nameof(AppsShown), nameof(TweaksShown), nameof(ReviewShown))]
    public partial string Mode { get; private set; } = "Choose";

    /// <summary>The step: 0 Apps, 1 Tweaks, 2 Review, 3 the run page and then the result.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsApps), nameof(IsTweaks), nameof(IsReview), nameof(IsRun), nameof(IsResult), nameof(AppsShown), nameof(TweaksShown), nameof(ReviewShown))]
    public partial int Step { get; private set; }

    /// <summary>A Run applies the Selection now.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsRun), nameof(IsResult))]
    public partial bool Running { get; private set; }

    public bool IsChoosing => Mode == "Choose";
    public bool IsGuided => Mode == "Guided";
    public bool IsApps => Step == 0;
    public bool IsTweaks => Step == 1;
    public bool IsReview => Step == 2;
    public bool IsRun => Step == 3 && Running;
    public bool IsResult => Step == 3 && !Running;
    public bool AppsShown => IsGuided && IsApps;
    public bool TweaksShown => IsGuided && IsTweaks;
    public bool ReviewShown => IsGuided && IsReview;

    /// <summary>The chooser's phases (statics don't bind).</summary>
    public IReadOnlyList<PhaseItem> PhaseList => Phases;

    [ObservableProperty]
    public partial TweaksStepViewModel Tweaks { get; private set; }

    [ObservableProperty]
    public partial AppsStepViewModel Apps { get; private set; }

    // ---- the header, the stepper and the footer

    [ObservableProperty]
    public partial string Heading { get; private set; } = "";

    [ObservableProperty]
    public partial string Subheading { get; private set; } = "";

    [ObservableProperty]
    public partial IReadOnlyList<StepItem> Stepper { get; private set; } = [];

    [ObservableProperty]
    public partial string NextText { get; private set; } = "Next";

    [ObservableProperty]
    public partial bool CanNext { get; private set; }

    [ObservableProperty]
    public partial bool CanBack { get; private set; }

    /// <summary>The footer: Guided's steps (not the result).</summary>
    [ObservableProperty]
    public partial bool ShowFooter { get; private set; }

    [ObservableProperty]
    public partial string StepLabel { get; private set; } = "";

    // ---- Review

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ReviewSide), nameof(ReviewMain))]
    public partial IReadOnlyList<ReviewGroup> Review { get; private set; } = [];

    /// <summary>Review's left column (the design's page D): the app groups, Remove and Install.</summary>
    public IReadOnlyList<ReviewGroup> ReviewSide => Review.Where(g => g.Title != TweaksGroup).ToList();

    /// <summary>Review's wider right column: the Tweaks group.</summary>
    public IReadOnlyList<ReviewGroup> ReviewMain => Review.Where(g => g.Title == TweaksGroup).ToList();

    private const string TweaksGroup = "Tweaks";

    [ObservableProperty]
    public partial (int Remove, int Install, int Tweaks) ReviewCounts { get; private set; }

    public string RemoveCount => $"{ReviewCounts.Remove}";
    public string InstallCount => $"{ReviewCounts.Install}";
    public string TweakCount => $"{ReviewCounts.Tweaks}";

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasRestartNote))]
    public partial string RestartNote { get; private set; } = "";

    public bool HasRestartNote => RestartNote.Length > 0;

    // ---- the run page and the result

    public ObservableCollection<RunItemViewModel> RunItems { get; } = [];

    [ObservableProperty]
    public partial double Progress { get; private set; }

    [ObservableProperty]
    public partial string ProgressText { get; private set; } = "";

    [ObservableProperty]
    public partial string ProgressLabel { get; private set; } = "";

    /// <summary>The last Run's Outcomes.</summary>
    [ObservableProperty]
    public partial IReadOnlyList<Outcome> Outcomes { get; private set; } = [];

    [ObservableProperty]
    public partial string ResultTitle { get; private set; } = "";

    [ObservableProperty]
    public partial string ResultText { get; private set; } = "";

    [ObservableProperty]
    public partial bool ResultReboot { get; private set; }

    [ObservableProperty]
    public partial (int Ok, int Bad, int Skipped) ResultCounts { get; private set; }

    public string OkCount => $"{ResultCounts.Ok}";
    public string BadCount => $"{ResultCounts.Bad}";
    public string SkipCount => $"{ResultCounts.Skipped}";

    [ObservableProperty]
    public partial IReadOnlyList<ResultItem> Failed { get; private set; } = [];

    [ObservableProperty]
    public partial IReadOnlyList<ResultItem> Skipped { get; private set; } = [];

    public bool HasFailed => Failed.Count > 0;
    public bool HasSkipped => Skipped.Count > 0;

    partial void OnReviewCountsChanged((int Remove, int Install, int Tweaks) value)
    {
        OnPropertyChanged(nameof(RemoveCount));
        OnPropertyChanged(nameof(InstallCount));
        OnPropertyChanged(nameof(TweakCount));
    }

    partial void OnResultCountsChanged((int Ok, int Bad, int Skipped) value)
    {
        OnPropertyChanged(nameof(OkCount));
        OnPropertyChanged(nameof(BadCount));
        OnPropertyChanged(nameof(SkipCount));
    }

    partial void OnFailedChanged(IReadOnlyList<ResultItem> value) => OnPropertyChanged(nameof(HasFailed));
    partial void OnSkippedChanged(IReadOnlyList<ResultItem> value) => OnPropertyChanged(nameof(HasSkipped));

    private TweaksStepViewModel NewTweaks() => new(_engine, _background, _dialogs, _text, Selection, Update, (preset, ids) => Apps.QuickSelect(preset, ids));

    private AppsStepViewModel NewApps() => new(_engine, _background, _dialogs, _icons, Selection, Update);

    /// <summary>The page was opened: its step's reads start.</summary>
    public void Shown()
    {
        if (IsGuided && Step == 0) { Apps.Ensure(); Tweaks.Ensure(); }
        if (IsGuided && Step == 1) Tweaks.Ensure();
        Update();
    }

    // ---- moving through the steps

    /// <summary>Guided's first step (the chooser's tile, Home's Choose changes).</summary>
    [RelayCommand]
    public void Guide()
    {
        if (Running) return;
        Go("Guided", 0);
    }

    /// <summary>Guided's Tweaks step with a preset's changes picked (Import): its apps too.</summary>
    public void GuideTweaks(Preset preset)
    {
        if (Running) return;
        Go("Guided", 1);
        Tweaks.QuickSelect(preset);
    }

    /// <summary>A Quick select from the toolbar: the preset replaces every pick, apps and Tweaks.</summary>
    [RelayCommand]
    public void QuickSelect(Preset preset) => Tweaks.QuickSelect(preset);

    private void Go(string mode, int step)
    {
        (Mode, Step) = (mode, step);
        if (step == 2) BuildReview();
        Shown();
    }

    [RelayCommand]
    public void Back()
    {
        if (Running) return;
        if (IsChoosing) { _navigator.Open("Home"); return; }
        if (Step is > 0 and <= 2) Go("Guided", Step - 1);
        else Go("Choose", 0);
    }

    [RelayCommand]
    public async Task NextAsync()
    {
        if (Running || IsChoosing) return;
        switch (Step)
        {
            case 2: await ApplyAsync(); break;
            case 3: Done(); break;
            default: Go("Guided", Step + 1); break;
        }
    }

    /// <summary>The title as a breadcrumb in Guided (Set-AkariHeader): Install AkariOS › the step; none on the chooser.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasCrumbs), nameof(HasNoCrumbs), nameof(CrumbLinks))]
    public partial IReadOnlyList<string> Crumbs { get; private set; } = [];

    public bool HasCrumbs => Crumbs.Count > 0;
    public bool HasNoCrumbs => Crumbs.Count == 0;

    /// <summary>The line above the heading: every crumb but the last, each a link.</summary>
    public IReadOnlyList<Shell.CrumbLink> CrumbLinks => [.. Crumbs.Take(Math.Max(0, Crumbs.Count - 1)).Select((c, i) => new Shell.CrumbLink(c, () => OpenCrumb(i)))];

    /// <summary>A crumb clicked (Open-AkariCrumb): Install AkariOS = the chooser, the picks kept; not while a Run applies.</summary>
    public void OpenCrumb(int index)
    {
        if (index != 0 || Running || IsChoosing) return;
        Go("Choose", 0);
    }

    // Update-AkariStepFooter and the header
    private void Update()
    {
        UpdateHeader();
        Crumbs = IsChoosing ? [] : ["Install AkariOS", Heading];
    }

    private void UpdateHeader()
    {
        var n = Selection.Count;
        if (IsChoosing)
        {
            (Heading, Subheading) = ("Install AkariOS", "Two ways to optimize Windows. Both make a restore point first.");
            Stepper = [];
            ShowFooter = false;
            return;
        }
        (Heading, Subheading) = Step switch
        {
            0 => ("Apps", "Pick the apps to remove and the apps to install"),
            1 => ("Tweaks", "Pick what to change. Hover a row for details."),
            2 => ("Review & Apply", "These changes run in one go, after an AkariOS restore point"),
            _ when Running => ("Applying", "Keep AkariOS open. Changes apply one after another; Explorer restarts once at the end."),
            _ => ("Done", "What happened to each change"),
        };
        var cur = Math.Min(Step, 2);
        Stepper = StepNames.Select((name, i) => new StepItem(i + 1, name, i < cur || Step > 2 ? "Done" : i == cur ? "Current" : "")).ToList();
        ShowFooter = Step < 3;
        StepLabel = Step < 3 ? $"Step {Step + 1} of 3 · {StepNames[Step]}" : "";
        CanBack = !Running;
        (NextText, CanNext) = Step switch
        {
            0 => ("Next", true),
            1 => ($"Review ({n})", n > 0),
            2 => ($"Apply {n} change{(n == 1 ? "" : "s")}", n > 0 && !Running),
            _ => ("Done", !Running),
        };
    }

    // ---- Review

    // Show-AkariReview: the counts, the restart note, a group each for Remove, Install, Tweaks (Hidden ones last)
    private void BuildReview()
    {
        var items = Selection.Values.ToList();
        var rm = new List<Pending>();
        var inst = new List<Pending>();
        var tw = new List<Pending>();
        foreach (var p in items)
        {
            var t = _engine.Find(p.Id);
            if (t?.Section == "Apps") (AppLists.IsRemoval(t) ? rm : inst).Add(p);
            else tw.Add(p);
        }
        ReviewCounts = (rm.Count, inst.Count, tw.Count);
        RestartNote = Core.Tweaks.Selection.RestartNote(items, _engine.Find) ?? "";
        static string S(int n, string what) => $"{n} {what}{(n == 1 ? "" : "s")}";
        ReviewRow Row(Pending p, string line) => new(p.Id, p.Name, line, CategoryGlyphs.Of(_engine.Find(p.Id)));
        var tweakRows = new List<ReviewRow>();
        foreach (var p in tw.Where(p => !p.Hidden)) tweakRows.Add(Row(p, Line(p)));
        if (tw.Any(p => p.Hidden)) tweakRows.Add(new ReviewRow("", "Advanced settings (Optimize › Advanced)", "", "", IsHeading: true));
        foreach (var p in tw.Where(p => p.Hidden)) tweakRows.Add(Row(p, Line(p)));
        Review =
        [
            new("", "Remove", S(rm.Count, "app"), rm.Select(p => Row(p, "Remove")).ToList(), false),
            new("", "Install", S(inst.Count, "app") + ", from winget where possible", inst.Select(p => Row(p, "Install")).ToList(), false),
            new("", TweaksGroup, S(tw.Count, "change"), tweakRows, true),
        ];
    }

    private static string Line(Pending p) => p.From.Length > 0 ? $"{p.From} → {p.To}" : p.To;

    // ---- Apply: one Run in the background, the restore point first

    /// <summary>Start-AkariApply: the Selection as one Run (Explorer restarted once, a change that restarts the PC
    /// last), after the session's restore point; Windows refusing one asks whether to go on without it.</summary>
    public async Task ApplyAsync(bool skipRestore = false)
    {
        if (Running || Selection.Count == 0 || !await FreeAsync()) return;
        var plan = Core.Tweaks.Selection.PlanItems(Selection.Values);
        var restore = !skipRestore && await _restore.ChooseAsync(Mode);
        Run(plan, restore);
    }

    // nothing else is changing the PC
    private async Task<bool> FreeAsync()
    {
        if (!_catalogue.Running && !_shell.IsBusy) return true;
        var what = _shell.Work.LastOrDefault()?.Label ?? "A change from Optimize";
        await _dialogs.ShowInfoAsync("Install AkariOS", $"{what} is still running. Apply these when it is done.");
        return false;
    }

    private sealed record Refused(string Message);

    private BusyWork? _busy;

    private void Run(IReadOnlyList<PlanItem> plan, bool restore)
    {
        var label = $"Applying {plan.Count} change{(plan.Count == 1 ? "" : "s")}";
        RunItems.Clear();
        if (restore) RunItems.Add(new RunItemViewModel("", "Create a restore point", "", "Preparation", ""));
        foreach (var i in plan) RunItems.Add(NewRunItem(i));
        (Progress, ProgressText, ProgressLabel) = (0, "0%", "Starting…");
        Running = true;
        Step = 3;
        _shell.Locked = true;
        _busy = _shell.Begin(label);
        _engine.Log.Write(label);
        Update();
        if (restore) RunItems[0].State = RunState.Working;
        var progress = new PostedProgress(_background, Report);
        _background.Run(() =>
        {
            if (restore && _engine.RestorePoints?.Create("AkariOS") is { Ok: false } refused) return new Refused(refused.Message);
            if (restore) _background.Post(() => RunItems[0].State = RunState.Applied);
            try
            {
                // X4: a history record for Settings › Recovery › Undo the last run
                return _engine.History is { } h
                    ? h.Record("Guided run", DateTime.Now, plan, _engine.Find, () => _engine.Runner.Run(plan, _engine.Find, progress))
                    : _engine.Runner.Run(plan, _engine.Find, progress);
            }
            catch (Exception e) { _engine.Log.WriteFile($"Error: Guided run: {e}"); return null; }
        }, r => _ = Guard(AppliedAsync(r, plan, restore)));
    }

    // New-AkariRunItems: the name says what happens, the kind where it comes from
    private RunItemViewModel NewRunItem(PlanItem i)
    {
        var t = _engine.Find(i.Id);
        if (t is null) return new RunItemViewModel(i.Id, i.Id, i.Id, "Change", CategoryGlyphs.Settings);
        var (name, kind) = t.Section == "Apps" && t.Category == "Remove" ? ($"Remove {t.Name}", t.Group == "appx" ? "Store app" : t.Group is not null ? "Windows feature" : "App")
            : t.Section == "Apps" ? ($"Install {t.Name}", t.Winget.Count > 0 ? "winget" : "AkariOS download")
            : (t.Name, $"Tweak · {t.Category}");
        return new RunItemViewModel(i.Id, name, t.Name, kind, CategoryGlyphs.Of(t));
    }

    // Update-AkariRunPage: the item the Runner names is Working, the one before it done; the bar and its percent
    private void Report(RunProgress p)
    {
        if (_busy is { } b) _shell.Report(b, p);
        foreach (var it in RunItems.Where(x => x.Kind != "Preparation"))
        {
            if (it.Plain != p.Step || it.State != RunState.Waiting) continue;
            foreach (var o in RunItems.Where(o => o != it && o.State == RunState.Working && o.Kind != "Preparation")) o.State = RunState.Applied;
            it.State = RunState.Working;
            ProgressLabel = $"{it.Name}…";
            break;
        }
        var pct = p.Total == 0 ? 1 : Math.Min(1, (double)p.Done / p.Total);
        Progress = pct * 100;
        ProgressText = $"{(int)Math.Round(pct * 100)}%";
    }

    private async Task AppliedAsync(object? r, IReadOnlyList<PlanItem> plan, bool restore)
    {
        Running = false;
        _shell.End(_busy);
        if (r is Refused refused)
        {
            // stopped before any change: back on Review; asked, then on without one (Cancel: Apply tries again). Still
            // locked while it asks, so the changes waiting in Optimize and Downloads don't start in between.
            Step = 2;
            Update();
            if (await _dialogs.ConfirmAsync("Restore point", $"AkariOS could not create a restore point:\n\n{refused.Message}\n\nApply the changes without a restore point?", "Apply anyway"))
            {
                _restore.Done = true;
                await ApplyAsync(skipRestore: true);
                if (!Running) _shell.Locked = false;
                return;
            }
            _shell.Locked = false;
            return;
        }
        // the changes that waited (Optimize's, Downloads') run now
        _shell.Locked = false;
        if (restore) _restore.Done = true;
        if (r is not IReadOnlyList<Outcome> outcomes)
        {
            Step = 2;
            Update();
            _shell.Toast("Install AkariOS stopped", "The changes stopped before they ran. The details are in akari.log.", InfoBarSeverity.Error);
            return;
        }
        // each row its Outcome
        foreach (var it in RunItems.Where(x => x.Kind != "Preparation"))
            if (outcomes.FirstOrDefault(o => o.Id == it.Id) is { } o)
                it.State = o.Kind switch
                {
                    OutcomeKind.Applied or OutcomeKind.Reverted => RunState.Applied,
                    OutcomeKind.Failed => RunState.Failed,
                    OutcomeKind.Already => RunState.Already,
                    _ => RunState.Skipped,
                };
        ShowResult(outcomes);
        // Last used (Quick select): what this Guided Run was asked to do
        try { _engine.Presets.SaveLastUsed(plan); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { _engine.Log.Write($"Warning: Last used not saved ({e.Message})"); }
        var ok = outcomes.Count(o => o.Kind is OutcomeKind.Applied or OutcomeKind.Reverted);
        _activity.Add("Guided run", "Install AkariOS", ok, "wand");
        // Complete-AkariApply's toast: "n changes applied", Restart now when a change needs it
        var bad = outcomes.Count(o => o.Kind == OutcomeKind.Failed);
        _shell.Toast("All done", $"{ok} change{(ok == 1 ? "" : "s")} applied." + (bad > 0 ? $" {bad} failed." : "") + (ResultReboot ? " Restart to finish." : ""),
            bad > 0 ? InfoBarSeverity.Warning : InfoBarSeverity.Success,
            ResultReboot && _engine.Shutdown is not null ? "Restart now" : null, () => _ = Guard(RestartNowAsync()));
        // what this PC has now: Home's facts and the Catalogue's States are read again
        _stats.Stale();
        _catalogue.NotifyApplied();
        Update();
    }

    // Show-AkariResult
    private void ShowResult(IReadOnlyList<Outcome> outcomes)
    {
        Outcomes = outcomes;
        var ok = outcomes.Count(o => o.Kind is OutcomeKind.Applied or OutcomeKind.Reverted);
        var bad = outcomes.Where(o => o.Kind == OutcomeKind.Failed).ToList();
        var skip = outcomes.Where(o => o.Kind is OutcomeKind.Skipped or OutcomeKind.Already).ToList();
        var (_, reboot) = Core.Tweaks.Selection.RunSummary(outcomes);
        ResultTitle = $"{ok} change{(ok == 1 ? "" : "s")} applied";
        ResultText = bad.Count > 0 ? $"{bad.Count} failed. See below." : "Everything went through.";
        ResultReboot = reboot;
        ResultCounts = (ok, bad.Count, skip.Count);
        string NameOf(Outcome o) => _engine.Find(o.Id)?.Name ?? o.Id;
        Failed = bad.Select(o => new ResultItem(NameOf(o), o.Message.Length > 0 ? o.Message : "It failed. Open the log for details.")).ToList();
        Skipped = skip.Select(o => new ResultItem(NameOf(o), o.Message.Length > 0 ? o.Message : o.Kind == OutcomeKind.Already ? "Already done." : "Skipped.")).ToList();
    }

    [RelayCommand]
    private void OpenLog() => _open.Folder(AkariPaths.UserFolder);

    [RelayCommand]
    private async Task RestartNowAsync()
    {
        if (_engine.Shutdown is not { } shutdown) return;
        if (!await _dialogs.ConfirmAsync("Restart", "Restart the PC now? Save your work first.", "Restart now")) return;
        _background.Run(() => { shutdown.Restart(); return null; }, _ => { });
    }

    /// <summary>Done (Reset-AkariSteps): the Selection forgotten, the chooser next time, Home.</summary>
    [RelayCommand]
    public void Done()
    {
        Reset();
        _navigator.Open("Home");
    }

    [RelayCommand]
    private void OpenRemoveApps() => _navigator.Open("Remove apps");

    [RelayCommand]
    private void OpenOptimize()
    {
        Reset();
        _navigator.Open("Optimize");
    }

    private void Reset()
    {
        if (Running) return;
        Selection.Clear();
        Outcomes = [];
        RunItems.Clear();
        (Tweaks, Apps) = (NewTweaks(), NewApps());
        (Mode, Step) = ("Choose", 0);
        Update();
    }

    // ---- One-click

    /// <summary>Start-AkariOneClick: asks first; the session's restore point here in the window (a refusal asks
    /// again); then the AkariOS preset is handed to Program's console and the window closes.</summary>
    [RelayCommand]
    public async Task StartOneClickAsync()
    {
        if (_shell.IsBusy || Running || _catalogue.Running)
        {
            await _dialogs.ShowInfoAsync("AkariOS One-click", "Wait until the changes running now are done, then start One-click.");
            return;
        }
        if (_engine.Presets.Find("AkariOS") is not { } preset)
        {
            await _dialogs.ShowErrorAsync("AkariOS One-click", "The AkariOS preset is missing from this build.");
            return;
        }
        var chassis = _engine.System.Chassis;
        var warning = chassis == Core.Machine.Chassis.Laptop ? OneClickWarning + LaptopNote : OneClickWarning;
        if (!await _dialogs.ConfirmAsync("Start One-click now?", warning, "Start One-click")) return;
        var browsers = OneClickPicks.Browsers(_engine.Loaded.Tweaks);
        string? browser = null;
        if (browsers.Count > 0)
        {
            var options = browsers.Select(b => b.Id == OneClickPicks.DefaultBrowser ? $"{b.Name} (recommended)" : b.Name).Append(NoBrowser).ToList();
            if (await _choice.PickAsync("Which browser should One-click install?", "AkariOS removes Microsoft Edge. Pick the browser to install instead.",
                    options, 0, "Continue") is not { } picked) return;
            browser = picked < browsers.Count ? browsers[picked].Id : null;
        }
        preset = OneClickPicks.Apply(preset, browser, chassis);
        foreach (var note in OneClickPicks.Notes(browser, chassis)) _engine.Log.WriteFile(note);
        if (!await _restore.ChooseAsync("OneClick")) { Hand(preset); return; }
        var busy = _shell.Begin("Creating a restore point");
        var done = new TaskCompletionSource<object?>();
        _background.Run(() => _engine.RestorePoints!.Create("AkariOS"), r => done.SetResult(r));
        var result = await done.Task;
        _shell.End(busy);
        if (result is RestoreResult { Ok: false } failed
            && !await _dialogs.ConfirmAsync("AkariOS One-click", $"AkariOS could not create a restore point:\n\n{failed.Message}\n\nRun AkariOS One-click without a restore point?", "Run anyway"))
        {
            _engine.Log.Write("One-click cancelled: no restore point.");
            return;
        }
        _restore.Done = true;
        Hand(preset);
    }

    private void Hand(Preset preset)
    {
        _engine.Log.WriteFile($"One-click started: {preset.Path}");
        _oneClick.Start(preset);
    }

    // ---- Import (Settings)

    /// <summary>Start-AkariImport: a preset file read; a copy in the user's presets (Quick select lists it); then
    /// Install AkariOS › Guided on its Tweaks step with the file's changes picked.</summary>
    public async Task ImportAsync()
    {
        if (Running || _shell.IsBusy || await _picker.OpenJsonAsync() is not { } path) return;
        string? text = null;
        try { text = File.ReadAllText(path); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { _engine.Log.Write($"Warning: {path} could not be read ({e.Message})"); }
        var preset = text is null ? null : _engine.Presets.Read(text, path, false);
        if (preset is not { Entries.Count: > 0 })
        {
            await _dialogs.ShowErrorAsync("Import settings", $"This file has no AkariOS settings in it:\n\n{path}");
            return;
        }
        try
        {
            Directory.CreateDirectory(_engine.Presets.UserFolder);
            var dest = Path.Combine(_engine.Presets.UserFolder, Path.GetFileName(path));
            if (!string.Equals(Path.GetFullPath(path), Path.GetFullPath(dest), StringComparison.OrdinalIgnoreCase)) File.Copy(path, dest, overwrite: true);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { _engine.Log.Write($"Warning: the imported file was not copied to the presets ({e.Message})"); }
        _engine.Log.Write($"Import: {path}");
        GuideTweaks(preset);
        var n = preset.Entries.Count;
        _shell.Toast($"Imported {Path.GetFileName(path)}", $"{n} choice{(n == 1 ? "" : "s")} loaded into Guided.", InfoBarSeverity.Informational);
        _navigator.Open("Install AkariOS");
    }

    private async Task Guard(Task task)
    {
        try { await task; }
        catch (Exception e)
        {
            _engine.Log.WriteFile($"Error: UI: {e}");
            if (!Running) _shell.Locked = false;
        }
    }
}
