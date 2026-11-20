using System.Collections.ObjectModel;
using AkariOS.App.Shell;
using AkariOS.Core.Iso;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>A build mode's card on the Start and Components steps: picked, or not available yet (a later batch).</summary>
public sealed partial class IsoModeViewModel(string id, string name, string description, string tag, string glyph, bool available, Action<string> pick) : ObservableObject
{
    [RelayCommand]
    private void Pick() => pick(Id);

    public string Id { get; } = id;
    public string Name { get; } = name;
    public string Description { get; } = description;
    public string Tag { get; } = tag;
    public string Glyph { get; } = glyph;
    public bool Available { get; } = available;

    [ObservableProperty]
    public partial bool IsSelected { get; set; }
}

/// <summary>A stage of the build on the Create ISO step: Waiting, Running, Done, Failed or Not run, and how long it
/// took.</summary>
public sealed partial class IsoStageViewModel(string text) : ObservableObject
{
    public string Text { get; } = text;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsWaiting), nameof(IsRunning), nameof(IsDone), nameof(IsFailed))]
    public partial string State { get; set; } = "Waiting";

    [ObservableProperty]
    public partial string Elapsed { get; set; } = "";

    public bool IsWaiting => State is "Waiting" or "Not run";
    public bool IsRunning => State == "Running";
    public bool IsDone => State == "Done";
    public bool IsFailed => State == "Failed";

    internal System.Diagnostics.Stopwatch? Clock { get; set; }

    /// <summary>Its operations as the build reports them (an expander under the stage).</summary>
    public ObservableCollection<IsoOpViewModel> Operations { get; } = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasOperations), nameof(NoOperations))]
    public partial string Summary { get; private set; } = "";

    public bool HasOperations => Summary.Length > 0;
    public bool NoOperations => !HasOperations;

    /// <summary>An operation reported: a new row while Running, then that row ends.</summary>
    public void Report(IsoOperation op)
    {
        var row = Operations.LastOrDefault(o => o.Name == op.Name && o.State == IsoOpState.Running);
        if (row is null || op.State == IsoOpState.Running) Operations.Add(new IsoOpViewModel(op));
        else row.End(op);
        var failed = Operations.Count(o => o.State == IsoOpState.Failed);
        var skipped = Operations.Count(o => o.State == IsoOpState.Skipped);
        Summary = $"{Operations.Count} {(Operations.Count == 1 ? "operation" : "operations")}"
            + (failed > 0 ? $", {failed} failed" : "") + (skipped > 0 ? $", {skipped} skipped" : "");
    }
}

/// <summary>One operation of a stage: its name, how it ended, the note (why it failed or was skipped) and its time.</summary>
public sealed partial class IsoOpViewModel(IsoOperation op) : ObservableObject
{
    public string Name { get; } = op.Name;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(StateText), nameof(IsRunning), nameof(IsDone), nameof(IsFailed), nameof(IsSkipped))]
    public partial IsoOpState State { get; private set; } = op.State;

    [ObservableProperty]
    public partial string Note { get; private set; } = op.Note;

    [ObservableProperty]
    public partial string Elapsed { get; private set; } = op.State == IsoOpState.Running ? "" : IsoBuilderViewModel.ElapsedText(op.Elapsed);

    public string StateText => State.ToString();
    public bool IsRunning => State == IsoOpState.Running;
    public bool IsDone => State == IsoOpState.Done;
    public bool IsFailed => State == IsoOpState.Failed;
    public bool IsSkipped => State == IsoOpState.Skipped;

    public void End(IsoOperation op)
    {
        Note = op.Note;
        Elapsed = IsoBuilderViewModel.ElapsedText(op.Elapsed);
        State = op.State;
    }
}

/// <summary>A Review card: its glyph, title and lines.</summary>
public sealed record IsoReviewCard(string Glyph, string Title, string Lines);

/// <summary>The ISO Builder's wizard (after Tiny11 Builder's layout, ideas only): Start, Windows image, Components,
/// Build settings, Review, Create ISO; Back and Next in the footer, Next only once a step is complete.</summary>
public sealed partial class IsoBuilderViewModel
{
    private IReadOnlyList<IsoModeViewModel>? _modes;

    public const int StartStep = 0, ImageStep = 1, ComponentsStep = 2, SettingsStep = 3, ReviewStep = 4, BuildStep = 5;

    public static IReadOnlyList<string> StepNames { get; } = ["Start", "Windows image", "Components", "Build settings", "Review", "Create ISO"];

    private static readonly string[] Headings =
    [
        "Make a Windows 11 ISO with what you don't want left out and AkariOS on it. Your own Windows and your ISO are not changed.",
        "An ISO you have, or one downloaded here. It is copied to a work folder, so the ISO itself is not changed.",
        "What the new Windows leaves out. Items an image doesn't have are skipped.",
        "How the new Windows is set up.",
        "Check the image, what goes and where the ISO is saved before building.",
        "Allow 20 to 40 minutes. Optimize's changes and installs wait meanwhile.",
    ];

    /// <summary>The modes (Start and Components). Only Custom until the modes batch (I4).</summary>
    public IReadOnlyList<IsoModeViewModel> Modes => _modes ??=
    [
        new("AkariOS", "AkariOS", "The AkariOS setup out of the box: its apps removed, its Tweaks applied, AkariOS on it.", "Coming soon", "\uE945", false, PickMode),
        new("Lite", "Lite", "A smaller Windows that keeps Windows Update, Defender, recovery and the Store.", "Coming soon", "\uE7F8", false, PickMode),
        new("Minimal", "Minimal", "The smallest image, for test VMs: no updates, recovery or Defender afterwards.", "Coming soon", "\uE74C", false, PickMode),
        new("Custom", "Custom", "Pick what to remove from the image's own apps and features.", "Choose yourself", "\uE713", true, PickMode),
    ];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsStart), nameof(IsImage), nameof(IsComponents), nameof(IsSettings), nameof(IsReview), nameof(IsBuild),
        nameof(Heading), nameof(Subheading))]
    public partial int Step { get; set; }

    public bool IsStart => Step == StartStep;
    public bool IsImage => Step == ImageStep;
    public bool IsComponents => Step == ComponentsStep;
    public bool IsSettings => Step == SettingsStep;
    public bool IsReview => Step == ReviewStep;
    public bool IsBuild => Step == BuildStep;

    public string Heading => Step == StartStep ? Title : StepNames[Step];
    public string Subheading => Headings[Step];

    /// <summary>The picked mode's id.</summary>
    [ObservableProperty]
    public partial string Mode { get; private set; } = "Custom";

    [ObservableProperty]
    public partial IReadOnlyList<StepItem> Stepper { get; private set; } = [];

    [ObservableProperty]
    public partial string StepLabel { get; private set; } = "";

    [ObservableProperty]
    public partial string NextText { get; private set; } = "Start";

    [ObservableProperty]
    public partial bool CanNext { get; private set; }

    [ObservableProperty]
    public partial bool CanBack { get; private set; }

    [ObservableProperty]
    public partial bool ShowFooter { get; private set; } = true;

    /// <summary>Why Next is off ("" when it isn't).</summary>
    [ObservableProperty]
    public partial string NextHint { get; private set; } = "";

    /// <summary>The image picked so far, beside every step ("No image yet" until an ISO is opened).</summary>
    [ObservableProperty]
    public partial string ImageSummary { get; private set; } = "No image yet";

    [ObservableProperty]
    public partial IReadOnlyList<IsoReviewCard> ReviewCards { get; private set; } = [];

    public ObservableCollection<IsoStageViewModel> Stages { get; } = [];

    /// <summary>The operation running now ("" between them), under the stages' heading.</summary>
    [ObservableProperty]
    public partial string CurrentOperation { get; private set; } = "";

    /// <summary>The ISO's size, SHA-256 and report file, once built.</summary>
    [ObservableProperty]
    public partial string ResultDetails { get; private set; } = "";

    // an operation reported by the build, onto the UI thread
    private sealed class PostedOps(IBackground background, Action<IsoOperation> show) : IProgress<IsoOperation>
    {
        public void Report(IsoOperation value) => background.Post(() => show(value));
    }

    private void ReportOperation(IsoOperation op)
    {
        if (op.Stage < 0 || op.Stage >= Stages.Count) return;
        Stages[op.Stage].Report(op);
        CurrentOperation = op.State == IsoOpState.Running ? op.Name : "";
    }

    /// <summary>A mode's card clicked: picked; on Start, also the next step.</summary>
    [RelayCommand]
    public void PickMode(string id)
    {
        var m = Modes.FirstOrDefault(x => x.Id == id);
        if (m is not { Available: true }) return;
        Mode = id;
        foreach (var x in Modes) x.IsSelected = x.Id == id;
        if (Step == StartStep) Step = ImageStep;
        UpdateWizard();
    }

    [RelayCommand]
    public async Task NextAsync()
    {
        if (!CanNext) return;
        if (Step == ReviewStep) { await BuildAsync(); return; }
        if (Step == BuildStep) { BuildAnother(); return; }
        Step++;
        UpdateWizard();
        // Custom's lists come from the edition itself: read them the first time Components opens
        if (Step == ComponentsStep && Mode == "Custom" && !List("Apps").Shown && Job is null) await ReadImageAsync();
    }

    [RelayCommand]
    public void Back()
    {
        if (!CanBack) return;
        Step = Step == BuildStep ? ReviewStep : Step - 1;
        UpdateWizard();
    }

    /// <summary>After a build: back to Start, the mode kept, for the next ISO.</summary>
    public void BuildAnother()
    {
        Stages.Clear();
        ResultPath = "";
        ResultDetails = "";
        CurrentOperation = "";
        BuildError = "";
        Step = StartStep;
        UpdateWizard();
    }

    partial void OnStepChanged(int value)
    {
        if (value == ReviewStep) ReviewCards = MakeReview();
    }

    partial void OnEditionIndexChanged(int value) => UpdateWizard();

    partial void OnJobChanged(string? value) => UpdateWizard();

    /// <summary>The stepper, the footer and the image summary, from the step and what is picked.</summary>
    public void UpdateWizard()
    {
        foreach (var x in Modes) x.IsSelected = x.Id == Mode;
        Stepper = [.. StepNames.Select((n, i) => new StepItem(i + 1, n, i < Step ? "Done" : i == Step ? "Current" : ""))];
        StepLabel = $"Step {Step + 1} of {StepNames.Count} · {StepNames[Step]}";
        ImageSummary = Edition is { } ed
            ? $"{ed.Name} · {ed.Version}"
            : "No image yet";
        var busy = Job is not null;
        CanBack = Step > StartStep && !busy && !(Step == BuildStep && HasResult);
        (NextText, NextHint) = Step switch
        {
            StartStep => ("Start", ""),
            ImageStep => ("Next", Edition is null ? "Open an ISO and pick an edition first." : ""),
            ComponentsStep => ("Next", ""),
            SettingsStep => ("Review", ""),
            ReviewStep => ("Build ISO", Edition is null ? "Open an ISO first (Windows image)." : ""),
            _ => ("Build another", HasResult || HasBuildError ? "" : "Building…"),
        };
        CanNext = !busy && NextHint.Length == 0;
        ShowFooter = true;
    }

    private IReadOnlyList<IsoReviewCard> MakeReview()
    {
        var mode = Modes.First(m => m.Id == Mode);
        var counts = Lists.Where(l => l.Shown).Select(l => $"{l.Title}: {l.Ticked().Length} of {l.Items.Count}").ToList();
        var answer = Answer switch
        {
            "None" => "None: setup asks everything as usual",
            "Local" => SkipOobe ? $"A local account ({User}), setup's questions skipped" : "A local account, setup asks the rest",
            _ => "The Unattend Generator's choices",
        };
        return
        [
            new("\uE7F8", "Windows image", $"{ImageSummary}\n{IsoPath.Trim()}"),
            new(mode.Glyph, mode.Name, counts.Count > 0 ? string.Join("\n", counts) : "Nothing removed: the image's lists weren't read."),
            new("\uE8B7", "Output and workspace", $"ISO\n{Path.Combine(OutDir.Trim(), IsoPlan.OutName(IsoPath.Trim()))}\n\nWork folder\n{IsoWork.Of(OutDir.Trim()).Root}"),
            new("\uE713", "Installation options", $"Answer file: {answer}\nAkariOS on the new Windows: {(AkariOS ? "Yes" : "No")}"),
        ];
    }

    // ---- the Create ISO step's stages

    private void StartStages(IReadOnlyList<IsoStep> steps)
    {
        Stages.Clear();
        foreach (var s in steps) Stages.Add(new IsoStageViewModel(s.Text));
    }

    // progress n of m: the stages before n done, n running (the build reports each step as it starts)
    private void ReportStage(int done, int total)
    {
        for (var i = 0; i < Stages.Count; i++)
        {
            var s = Stages[i];
            var state = i < done || done >= total ? "Done" : i == done ? "Running" : "Waiting";
            if (state == s.State) continue;
            if (state == "Running") s.Clock = System.Diagnostics.Stopwatch.StartNew();
            if (state == "Done" && s.Clock is { } c) s.Elapsed = ElapsedText(c.Elapsed);
            s.State = state;
        }
    }

    // the build ended: the report's states and times where it has them, else the running stage done or failed and
    // the rest done or not run
    private void EndStages(bool ok, IsoReport? report = null)
    {
        CurrentOperation = "";
        if (report is not null && report.Stages.Count == Stages.Count)
        {
            for (var i = 0; i < Stages.Count; i++)
            {
                Stages[i].State = report.Stages[i].State;
                Stages[i].Elapsed = report.Stages[i].State == "Not run" ? "" : ElapsedText(TimeSpan.FromSeconds(report.Stages[i].Seconds));
            }
            ResultDetails = ok
                ? $"{report.Size / 1024.0 / 1024 / 1024:0.00} GB · SHA-256 {report.Sha256}\nReport: {IsoReport.FileFor(report.Iso)}"
                : $"Report: {IsoReport.FileFor(report.Iso)}";
            return;
        }
        foreach (var s in Stages)
        {
            if (s.State == "Running")
            {
                if (s.Clock is { } c) s.Elapsed = ElapsedText(c.Elapsed);
                s.State = ok ? "Done" : "Failed";
            }
            else if (s.State == "Waiting") s.State = ok ? "Done" : "Not run";
        }
    }

    public static string ElapsedText(TimeSpan t) => t.TotalMinutes >= 1 ? $"{(int)t.TotalMinutes} min {t.Seconds} s" : $"{Math.Max(0, (int)t.TotalSeconds)} s";
}
