using System.Collections.ObjectModel;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Apps;
using AkariOS.Core.Iso;
using AkariOS.Core.Machine;
using AkariOS.Core.Unattend;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.ViewModels;

/// <summary>The ISO Builder's engine parts: the build and the downloads (null where there are none), and the exe an
/// image gets as AkariOS (null for a developer build).</summary>
public sealed record IsoTools(IsoBuild? Build, IsoDownload? Download, string? AkariExe)
{
    /// <summary>The real ones on the engine's parts: DISM, the hives, the ISO drive, UUP Dump and Massgrave; this exe
    /// unless it is a developer build (Program's IsoBuild / IsoDownload in the WPF app).</summary>
    public static IsoTools Live(Engine engine)
    {
        var tw = engine.Services;
        var build = new IsoBuild(IsoParts.Live(engine.Files, engine.Registry, tw.Trusted!, tw.Exe!, tw.Http!, tw.Shortcuts!, engine.Log));
        var download = new IsoDownload(IsoDownloadParts.Live(tw.Http!, tw.Exe!, engine.Log, engine.Registry));
        return new(build, download, UpdateService.IsDeveloperBuild() ? null : Environment.ProcessPath);
    }
}

/// <summary>A row of one of the image's lists: its label, the name removed, ticked.</summary>
public sealed partial class ImageItemViewModel(string label, string value, AppIcon? icon = null) : ObservableObject
{
    public string Label { get; } = label;
    public string Value { get; } = value;

    /// <summary>A Store app's icon (the image's own logo); null for the other lists.</summary>
    public AppIcon? Icon { get; } = icon;
    public bool HasIcon => Icon is not null;

    [ObservableProperty]
    public partial bool IsChecked { get; set; }
}

/// <summary>One of the image's four lists (Store apps, Optional features, Windows features, OS packages): hidden until
/// the image is read, its heading with the count.</summary>
public sealed partial class ImageListViewModel(string kind, string title) : ObservableObject
{
    public string Kind { get; } = kind;
    public string Title { get; } = title;

    public ObservableCollection<ImageItemViewModel> Items { get; } = [];

    [ObservableProperty]
    public partial bool Shown { get; private set; }

    [ObservableProperty]
    public partial string Heading { get; private set; } = "";

    public void Set(IEnumerable<(string Label, string Value)> items) => Set(items.Select(i => (i.Label, i.Value, (AppIcon?)null)));

    public void Set(IEnumerable<(string Label, string Value, AppIcon? Icon)> items)
    {
        Items.Clear();
        foreach (var (label, value, icon) in items.OrderBy(i => i.Label, StringComparer.CurrentCultureIgnoreCase)) Items.Add(new(label, value, icon));
        Heading = $"{Title} ({Items.Count})";
        Shown = true;
    }

    public void Reset()
    {
        Items.Clear();
        Heading = "";
        Shown = false;
    }

    public string[] Ticked() => [.. Items.Where(i => i.IsChecked).Select(i => i.Value)];
}

/// <summary>
/// The ISO Builder: a custom Windows 11 ISO through a six-step wizard (plan docs/plans/2026-11-20-iso-builder-wizard.md;
/// the steps in IsoBuilderViewModel.Wizard.cs): Start (the mode), Windows image (a file, UUP Dump, Massgrave; the work
/// and output folder; Open ISO; the edition), Components (the image's own lists), Build settings (the answer file,
/// AkariOS), Review, Create ISO (its stages). One per app. Every slow step is a
/// job through <see cref="IBackground"/>, one at a time (Start-AkariIsoJob): the long ones (Open, Read, Build, the UUP
/// download) lock the shell, so Optimize's changes and Downloads' installs wait, and are refused while anything else
/// runs; the questions to a website (UUP Dump's lists, Massgrave's) don't.
/// </summary>
public sealed partial class IsoBuilderViewModel : ObservableObject
{
    public const string Title = "ISO Builder";

    /// <summary>The jobs that lock the shell (closing names them, a half-built image is discarded at the next launch).</summary>
    public static IReadOnlyList<string> LongJobs { get; } = ["IsoOpen", "IsoRead", "IsoBuild", "IsoUup"];

    public const string MassgraveHint = "Massgrave's links go to file hosts AkariOS can't download from: your browser does, then AkariOS finds the file in Downloads.";

    private readonly Engine _engine;
    private readonly IsoTools _tools;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly ShellState _shell;
    private readonly IFilePicker _picker;
    private readonly IShellOpen _open;
    private readonly ITimers _timers;
    private readonly CatalogueViewModel _catalogue;
    private readonly UnattendViewModel _unattend;
    private readonly IShellNavigator _navigator;

    private BusyWork? _busy;
    private readonly AppIcons _icons;

    /// <summary>Where the image's app logos are copied (the image is unmounted after a build).</summary>
    public string LogoFolder { get; set; } = Path.Combine(AkariPaths.UserFolder, "IsoLogos");
    private string _label = "";
    private bool _filling;
    private string _image = "";
    private IReadOnlyList<IsoEdition> _editions = [];
    private IReadOnlyList<ImageApp>? _imageApps;
    private UupBuild? _uupBuild;
    private IReadOnlyList<UupLanguage> _uupLangs = [];
    private IReadOnlyList<UupTarget> _uupTargets = [];
    private IReadOnlyList<MassgraveIso> _massgrave = [];
    private IReadOnlyList<MassgraveIso> _mgFiles = [];
    private string _waiting = "";
    private IDisposable? _watch;

    public IsoBuilderViewModel(Engine engine, IsoTools tools, IBackground background, IDialogService dialogs, ShellState shell, IFilePicker picker,
        IShellOpen open, ITimers timers, CatalogueViewModel catalogue, UnattendViewModel unattend, IShellNavigator navigator, AppIcons icons)
    {
        (_engine, _tools, _background, _dialogs, _shell, _picker, _open, _timers, _catalogue, _unattend, _navigator, _icons) =
            (engine, tools, background, dialogs, shell, picker, open, timers, catalogue, unattend, navigator, icons);
        try { OutDir = UserFolders.Get(engine.Registry, "Downloads") ?? ""; }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Security.SecurityException or InvalidOperationException) { OutDir = ""; }
        if (tools.AkariExe is null)
        {
            AkariOS = false;
            AkariOSEnabled = false;
            AkariOSNote = "Not in a developer build: only the published AkariOS-Native.exe can be copied into the image.";
        }
        UpdateWizard();
    }

    // ---- the job (Start-AkariIsoJob, Complete-AkariIsoJob)

    /// <summary>The running job's kind (IsoOpen, IsoRead, IsoBuild, IsoUup, IsoUupList, IsoMassgrave), else null.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Running), nameof(Working), nameof(Idle))]
    public partial string? Job { get; private set; }

    public bool Running => Job is not null;
    public bool Idle => Job is null;

    /// <summary>One of the long jobs runs (the shell is locked meanwhile).</summary>
    public bool Working => Job is not null && LongJobs.Contains(Job);

    /// <summary>Starts a job unless the ISO Builder or (for a long one) anything else is working: its label in the log
    /// and on the busy toast, the work in the background, then <paramref name="done"/> with the job cleared.</summary>
    private async Task<bool> StartAsync(string kind, string label, Func<object?> work, Action<object?> done)
    {
        var isLong = LongJobs.Contains(kind);
        if (Job is not null)
        {
            await _dialogs.ShowInfoAsync(Title, $"The ISO Builder is still working ({_label}). Try again when it is done.");
            return false;
        }
        if (isLong && (_shell.IsBusy || _shell.Locked || _catalogue.Running))
        {
            await _dialogs.ShowInfoAsync(Title, "Wait until the changes running now are done, then try again.");
            return false;
        }
        Job = kind;
        _label = label;
        if (isLong) _shell.Locked = true;
        _busy = _shell.Begin(label);
        _engine.Log.Write(label);
        _background.Run(work, r =>
        {
            Job = null;
            _shell.End(_busy);
            _busy = null;
            if (isLong) _shell.Locked = false;
            done(r);
        });
        return true;
    }

    // ---- 1 the ISO

    /// <summary>The ISO's source: File, Microsoft, Uup or Massgrave (Microsoft's hash list and Massgrave's list are
    /// read the first time).</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsFile), nameof(IsMicrosoft), nameof(IsUup), nameof(IsMassgrave))]
    public partial string Source { get; set; } = "File";

    public bool IsFile { get => Source == "File"; set { if (value) Source = "File"; } }
    public bool IsMicrosoft { get => Source == "Microsoft"; set { if (value) Source = "Microsoft"; } }
    public bool IsUup { get => Source == "Uup"; set { if (value) Source = "Uup"; } }
    public bool IsMassgrave { get => Source == "Massgrave"; set { if (value) Source = "Massgrave"; } }

    partial void OnSourceChanged(string value)
    {
        if (value == "Massgrave" && _massgrave.Count == 0 && Job != "IsoMassgrave") _ = MassgraveListAsync();
        if (value == "Microsoft" && _msHashes is null && Job != "IsoMicrosoft") _ = MicrosoftHashesAsync();
    }

    [ObservableProperty]
    public partial string IsoPath { get; set; } = "";

    // another ISO: the last one's note no longer applies
    partial void OnIsoPathChanged(string value) => OpenNote = "";

    /// <summary>The work and output folder (the real user's Downloads at first).</summary>
    [ObservableProperty]
    public partial string OutDir { get; set; } = "";

    [ObservableProperty]
    public partial string OpenNote { get; private set; } = "";

    [RelayCommand]
    public async Task PickIsoAsync()
    {
        if (await _picker.OpenIsoAsync() is { } f) IsoPath = f;
    }

    [RelayCommand]
    public async Task PickFolderAsync()
    {
        if (await _picker.FolderAsync() is { } f) OutDir = f;
    }

    /// <summary>Open ISO (Start-AkariIsoOpen): copied to the work folder, its editions read.</summary>
    [RelayCommand]
    public async Task OpenIsoAsync()
    {
        BuildError = "";
        var iso = IsoPath.Trim();
        var outDir = OutDir.Trim();
        if (iso.Length == 0 || !File.Exists(iso)) { OpenNote = "Pick an ISO file first (or download one above)."; return; }
        if (outDir.Length == 0) { OpenNote = "Pick a work and output folder."; return; }
        if (_tools.Build is not { } build) { OpenNote = "Not opened: the ISO Builder isn't available here."; return; }
        await StartAsync("IsoOpen", "Copying the ISO and reading its editions", () =>
        {
            try { return build.Open(iso, outDir); }
            catch (Exception e) { return e.Message; }
        }, r =>
        {
            if (r is not IsoSource src) { OpenNote = $"Not opened: {r as string ?? "see the log"}"; return; }
            _image = src.Image;
            ResetLists();
            _editions = [.. src.Editions.Where(e => e.Supported)];
            Editions = [.. _editions.Select(e => $"{e.Name} ({e.Version})")];
            // Pro when the ISO has it, else the first
            var pro = _editions.ToList().FindIndex(e => e.Name.EndsWith(" Pro", StringComparison.OrdinalIgnoreCase));
            EditionIndex = _editions.Count > 0 ? Math.Max(0, pro) : -1;
            OpenNote = $"Opened: {_editions.Count} Windows 11 editions.";
        });
    }

    // a downloaded ISO becomes the source: "An ISO file I have", ready to open (Set-AkariIsoSource)
    private void SetSource(string path, string note)
    {
        IsoPath = path;
        Source = "File";
        OpenNote = $"{note}. Press Open ISO.";
        _engine.Log.Write($"ISO Builder: {note}");
    }

    // ---- UUP Dump

    public IReadOnlyList<string> UupVersions { get; } = [.. Uup.Versions.Select(v => $"Windows 11 {v.Version}")];

    [ObservableProperty]
    public partial int UupVersionIndex { get; set; } = -1;

    [ObservableProperty]
    public partial IReadOnlyList<string> UupLanguages { get; private set; } = [];

    [ObservableProperty]
    public partial int UupLanguageIndex { get; set; } = -1;

    [ObservableProperty]
    public partial IReadOnlyList<string> UupEditions { get; private set; } = [];

    [ObservableProperty]
    public partial int UupEditionIndex { get; set; } = -1;

    [ObservableProperty]
    public partial string UupNote { get; private set; } = "Pick a version. UUP Dump builds the ISO from Microsoft's own files: allow 20 to 60 minutes.";

    public string UupLanguage => Pick(_uupLangs, UupLanguageIndex)?.Name ?? "";
    public string UupEdition => Pick(_uupTargets, UupEditionIndex)?.Label ?? "";

    private static T? Pick<T>(IReadOnlyList<T> list, int i) where T : class => i >= 0 && i < list.Count ? list[i] : null;

    private string? UupVersion => UupVersionIndex >= 0 && UupVersionIndex < Uup.Versions.Count ? Uup.Versions[UupVersionIndex].Version : null;

    partial void OnUupVersionIndexChanged(int value)
    {
        if (!_filling) _ = UupVersionPickedAsync();
    }

    partial void OnUupLanguageIndexChanged(int value)
    {
        if (!_filling) _ = UupEditionsAsync();
    }

    // a version picked: its newest build and languages (en-us picked), then its editions
    private async Task UupVersionPickedAsync()
    {
        if (UupVersion is not { } v || _tools.Download is not { } dl) return;
        SetLanguages([]);
        SetTargets([]);
        await StartAsync("IsoUupList", $"Asking UUP Dump for Windows 11 {v}", () =>
        {
            var b = dl.Build(v);
            return (b, b.Ok ? dl.Languages(b.Value!.Id) : null);
        }, r =>
        {
            if (r is not ValueTuple<UupAnswer<UupBuild>, UupAnswer<IReadOnlyList<UupLanguage>>?> (var b, var langs)) { UupNote = "UUP Dump could not be asked: see the log."; return; }
            if (!b.Ok) { UupNote = b.Message; return; }
            _uupBuild = b.Value;
            if (langs is not { Ok: true }) { UupNote = langs?.Message ?? ""; return; }
            UupNote = $"{b.Value!.Title}. Pick a language and an edition.";
            var list = langs.Value!.OrderBy(l => l.Name, StringComparer.CurrentCultureIgnoreCase).ToList();
            SetLanguages(list, Math.Max(0, list.FindIndex(l => l.Code == "en-us")));
            _ = UupEditionsAsync();
        });
    }

    private void SetLanguages(IReadOnlyList<UupLanguage> list, int pick = -1)
    {
        _filling = true;
        try
        {
            _uupLangs = list;
            UupLanguages = [.. list.Select(l => l.Name)];
            UupLanguageIndex = list.Count > 0 ? pick : -1;
        }
        finally { _filling = false; }
    }

    private void SetTargets(IReadOnlyList<UupTarget> list, int pick = -1)
    {
        _uupTargets = list;
        UupEditions = [.. list.Select(t => t.Label)];
        UupEditionIndex = list.Count > 0 ? pick : -1;
    }

    // a language picked: its editions (Pro picked)
    private async Task UupEditionsAsync()
    {
        if (Pick(_uupLangs, UupLanguageIndex) is not { } lang || _uupBuild is not { } build || _tools.Download is not { } dl) return;
        await StartAsync("IsoUupList", "Asking UUP Dump for its editions", () => dl.Editions(build.Id, lang.Code), r =>
        {
            if (r is not UupAnswer<IReadOnlyList<UupTarget>> e) { UupNote = "UUP Dump could not be asked: see the log."; return; }
            if (!e.Ok) { UupNote = e.Message; return; }
            var list = e.Value!.ToList();
            SetTargets(list, Math.Max(0, list.FindIndex(t => t.Label == "Pro")));
        });
    }

    /// <summary>Download (Start-AkariUupDownload): asked first, then UUP Dump's converter builds the ISO; it becomes the
    /// source.</summary>
    [RelayCommand]
    public async Task UupDownloadAsync()
    {
        var (v, lang, t) = (UupVersion, Pick(_uupLangs, UupLanguageIndex), Pick(_uupTargets, UupEditionIndex));
        if (v is null || lang is null || t is null || _uupBuild is not { } build) { UupNote = "Pick a version, a language and an edition first."; return; }
        var outDir = OutDir.Trim();
        if (outDir.Length == 0) { UupNote = "Pick a work and output folder below first."; return; }
        if (_tools.Download is not { } dl) return;
        var q = $"Download Windows 11 {v} {t.Label} ({lang.Name}) with UUP Dump?\n\nIt downloads several GB from Microsoft and builds the ISO: allow 20 to 60 minutes. AkariOS can't be used meanwhile.";
        if (!await _dialogs.ConfirmAsync("Download with UUP Dump?", q, "Download")) return;
        await StartAsync("IsoUup", $"Downloading Windows 11 {v} {t.Label}", () => dl.SaveUup(v, build, lang.Code, t, outDir), r =>
        {
            if (r is IsoResult { Ok: true, Path: { } path })
            {
                SetSource(path, $"Downloaded: {path}");
                _shell.Toast("Windows 11 downloaded", path);
            }
            else
            {
                UupNote = $"Not downloaded: {(r as IsoResult)?.Message ?? "see the log"}";
                _shell.Toast("Not downloaded", (r as IsoResult)?.Message ?? "See the log.", InfoBarSeverity.Error);
            }
        });
    }

    // ---- Massgrave

    [ObservableProperty]
    public partial IReadOnlyList<string> MassgraveProducts { get; private set; } = [];

    [ObservableProperty]
    public partial int MassgraveProductIndex { get; set; } = -1;

    [ObservableProperty]
    public partial IReadOnlyList<string> MassgraveFiles { get; private set; } = [];

    [ObservableProperty]
    public partial int MassgraveFileIndex { get; set; } = -1;

    [ObservableProperty]
    public partial string MassgraveNote { get; private set; } = MassgraveHint;

    partial void OnMassgraveProductIndexChanged(int value)
    {
        if (value < 0 || value >= MassgraveProducts.Count) return;
        _mgFiles = Massgrave.Files(_massgrave, MassgraveProducts[value]);
        MassgraveFiles = [.. _mgFiles.Select(f => f.Language)];
        MassgraveFileIndex = _mgFiles.Count > 0 ? 0 : -1;
    }

    private async Task MassgraveListAsync()
    {
        if (_tools.Download is not { } dl) return;
        MassgraveNote = "Reading Massgrave's list…";
        await StartAsync("IsoMassgrave", "Reading Massgrave's list", () => dl.Catalogue(), r =>
        {
            if (r is not UupAnswer<IReadOnlyList<MassgraveIso>> c) { MassgraveNote = "Massgrave's list could not be read: see the log."; return; }
            if (!c.Ok) { MassgraveNote = c.Message; return; }
            _massgrave = c.Value!;
            MassgraveProducts = Massgrave.Products(_massgrave);
            MassgraveProductIndex = -1;
            MassgraveProductIndex = MassgraveProducts.Count > 0 ? 0 : -1;
            MassgraveNote = "Pick an ISO and open its page. " + MassgraveHint;
        });
    }

    /// <summary>Opens the chosen file's page in the browser, then looks for it in Downloads every 3 seconds.</summary>
    [RelayCommand]
    public void OpenMassgravePage()
    {
        if (Pick(_mgFiles, MassgraveFileIndex) is not { } f) return;
        _open.Url(f.Url);
        _waiting = f.File;
        MassgraveNote = $"Waiting for {f.File} in Downloads… (download it in the browser that just opened)";
        _watch ??= _timers.Every(TimeSpan.FromSeconds(3), CheckDownload);
    }

    private void CheckDownload()
    {
        if (_msWaiting) { CheckMicrosoftDownload(); return; }
        if (_waiting.Length == 0 || _tools.Download is not { } dl) { StopWatch(); return; }
        if (dl.FindDownloaded(_waiting) is not { } hit) return;
        StopWatch();
        _waiting = "";
        SetSource(hit, $"Downloaded: {hit}");
        _shell.Toast("ISO found in Downloads", hit, InfoBarSeverity.Informational);
    }

    private void StopWatch()
    {
        _watch?.Dispose();
        _watch = null;
    }

    // ---- Microsoft (batch I5): the browser downloads from Microsoft's page, AkariOS finds the ISO and checks it

    public const string MicrosoftHint = "Microsoft's page downloads the latest Windows 11 in your browser (pick the language there); AkariOS then finds it in Downloads and checks it against the SHA-256 values Microsoft publishes.";

    private IReadOnlyList<MicrosoftHash>? _msHashes;
    private string _msHashError = "";
    private bool _msWaiting;
    private DateTime _msSince;

    [ObservableProperty]
    public partial string MicrosoftNote { get; private set; } = MicrosoftHint;

    // Microsoft's hash table, read once (a question to a website: not a long job)
    private async Task MicrosoftHashesAsync()
    {
        if (_tools.Download is not { } dl) return;
        await StartAsync("IsoMicrosoft", "Reading Microsoft's SHA-256 list", () => dl.MicrosoftHashes(), r =>
        {
            if (r is UupAnswer<IReadOnlyList<MicrosoftHash>> { Ok: true, Value: { } rows })
            {
                _msHashes = rows;
                _msHashError = "";
            }
            else
            {
                _msHashError = (r as UupAnswer<IReadOnlyList<MicrosoftHash>>)?.Message ?? "Microsoft's SHA-256 list could not be read.";
                _engine.Log.WriteFile($"ISO Builder: {_msHashError}");
            }
        });
    }

    /// <summary>Opens Microsoft's page in the browser, then looks for a new Win11*.iso in Downloads every 3 seconds.</summary>
    [RelayCommand]
    public void OpenMicrosoftPage()
    {
        _open.Url(MicrosoftIso.Page);
        _msWaiting = true;
        // a file the browser finishes from now on (a few seconds' slack for the clocks)
        _msSince = DateTime.UtcNow.AddSeconds(-5);
        MicrosoftNote = "Waiting for the Windows 11 ISO in Downloads… (choose the language and download it in the browser that just opened)";
        _watch ??= _timers.Every(TimeSpan.FromSeconds(3), CheckDownload);
    }

    private void CheckMicrosoftDownload()
    {
        if (_tools.Download is not { } dl) { StopWatch(); return; }
        if (Job is not null || dl.FindNew(MicrosoftIso.FilePattern, _msSince) is not { } hit) return;
        // the hash list not read yet (its read was refused while another job ran): read it, check on the next tick
        if (_msHashes is null && _msHashError.Length == 0) { _ = MicrosoftHashesAsync(); return; }
        StopWatch();
        _msWaiting = false;
        _ = CheckMicrosoftIsoAsync(dl, hit);
    }

    // the download checked against Microsoft's table: a match becomes the source; none = it isn't used
    private async Task CheckMicrosoftIsoAsync(IsoDownload dl, string iso)
    {
        var hashes = _msHashes;
        if (hashes is null)
        {
            SetSource(iso, $"Downloaded: {iso} (not checked: {_msHashError.TrimEnd('.')})");
            MicrosoftNote = MicrosoftHint;
            return;
        }
        MicrosoftNote = $"Checking {Path.GetFileName(iso)} against Microsoft's SHA-256 values…";
        await StartAsync("IsoVerify", "Checking the ISO's SHA-256", () =>
        {
            try { return dl.Check(iso, hashes) ?? (object)"none"; }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return e; }
        }, r =>
        {
            switch (r)
            {
                case MicrosoftHash h:
                    MicrosoftNote = MicrosoftHint;
                    SetSource(iso, $"Downloaded and checked against Microsoft's SHA-256 ({h.Language}): {iso}");
                    _shell.Toast("ISO found and checked", iso, InfoBarSeverity.Success);
                    break;
                case Exception e:
                    MicrosoftNote = $"{Path.GetFileName(iso)} could not be read: {e.Message}";
                    break;
                default:
                    MicrosoftNote = $"{Path.GetFileName(iso)} doesn't match any SHA-256 value Microsoft publishes: it may be damaged or not Microsoft's. Delete it and download it again.";
                    _engine.Log.WriteFile($"ISO Builder: {iso} matches no SHA-256 on Microsoft's page");
                    _shell.Toast("ISO not used", "Its SHA-256 doesn't match Microsoft's.", InfoBarSeverity.Warning);
                    break;
            }
        });
    }

    // ---- 2 the edition

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(EditionEnabled))]
    public partial IReadOnlyList<string> Editions { get; private set; } = [];

    [ObservableProperty]
    public partial int EditionIndex { get; set; } = -1;

    public bool EditionEnabled => Editions.Count > 0;

    /// <summary>The edition picked in the opened ISO, else null.</summary>
    public IsoEdition? Edition =>_image.Length > 0 ? Pick(_editions, EditionIndex) : null;

    // ---- 3 the answer file

    /// <summary>None, Local or Generator.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(AnswerNone), nameof(AnswerLocal), nameof(AnswerGenerator))]
    public partial string Answer { get; set; } = "Local";

    public bool AnswerNone { get => Answer == "None"; set { if (value) Answer = "None"; } }
    public bool AnswerLocal { get => Answer == "Local"; set { if (value) Answer = "Local"; } }
    public bool AnswerGenerator { get => Answer == "Generator"; set { if (value) Answer = "Generator"; } }

    [ObservableProperty]
    public partial bool SkipOobe { get; set; } = true;

    [ObservableProperty]
    public partial string User { get; set; } = "Admin";

    [ObservableProperty]
    public partial string Password { get; set; } = "";

    [RelayCommand]
    public void OpenUnattend() => _navigator.Open("Install USB");

    // ---- 6 the image's lists

    public IReadOnlyList<ImageListViewModel> Lists { get; } =
        [new("Apps", "Store apps"), new("Capabilities", "Optional features"), new("Features", "Windows features"), new("Packages", "OS packages (advanced)")];

    public ImageListViewModel List(string kind) => Lists.Single(l => l.Kind == kind);

    [ObservableProperty]
    public partial string ListNote { get; private set; } = "Open the ISO first: the lists come from the edition itself (mounting it takes a few minutes).";

    private sealed record ImageLists(IReadOnlyList<ImageApp> Apps, IReadOnlyList<AppIcon> Icons, IReadOnlyList<DismItem> Capabilities, IReadOnlyList<DismItem> Features, IReadOnlyList<DismItem> Packages);

    /// <summary>Read the image's apps (Start-AkariIsoRead): the edition mounted, its four lists read.</summary>
    [RelayCommand]
    public async Task ReadImageAsync()
    {
        if (Edition is not { } ed) { ListNote = "Open the ISO and pick an edition first."; return; }
        if (_tools.Build is not { } build) return;
        var outDir = OutDir.Trim();
        var image = _image;
        var progress = new PostedProgress(_background, p => { if (_busy is { } b) _shell.Report(b, p); });
        var log = _engine.Log;
        var logoFolder = LogoFolder;
        await StartAsync("IsoRead", $"Reading the apps in {ed.Name}", () =>
        {
            // each step on the busy toast and, timed, in akari.log
            T Step<T>(int done, string text, Func<T> work)
            {
                progress.Report(new Core.Runs.RunProgress(done, 3, text));
                var clock = System.Diagnostics.Stopwatch.StartNew();
                var r = work();
                log.WriteFile($"ISO Builder: {text}: {clock.Elapsed.TotalSeconds:0} s");
                return r;
            }
            try
            {
                var w = IsoWork.Of(outDir);
                Step(0, "Exporting and mounting the edition (the first time only)", () => { build.MountEdition(w, image, ed.Index); return 0; });
                var apps = Step(1, "Reading the Store apps and their icons", () => build.Apps(w.Mount));
                var logos = build.AppLogos(w.Mount, apps, logoFolder);
                var icons = apps.Select(a => _icons.OfPackage(a.Name, logos)).ToList();
                var items = Step(2, "Reading the features and packages", () => build.Items(w.Mount));
                return new ImageLists(apps, icons, items.Capabilities,
                    [.. items.Features.Where(f => !f.State.Contains("Disabled", StringComparison.OrdinalIgnoreCase))], items.Packages);
            }
            catch (Exception e) { return e.Message; }
        }, r =>
        {
            if (r is not ImageLists l) { ListNote = $"Not read: {r as string ?? "see the log"}"; return; }
            _imageApps = l.Apps;
            List("Apps").Set(l.Apps.Select((a, i) => (a.Name, a.Package, (AppIcon?)l.Icons[i])));
            List("Capabilities").Set(l.Capabilities.Select(c => (c.Name, c.Name)));
            List("Features").Set(l.Features.Select(f => (f.Name, f.Name)));
            List("Packages").Set(l.Packages.Select(p => (p.Name, p.Name)));
            ListNote = "Tick what to remove. Frameworks are left out of the list (apps need them).";
        });
    }

    private void ResetLists()
    {
        _imageApps = null;
        foreach (var l in Lists) l.Reset();
    }

    /// <summary>Select recommended: the image's apps Win11Debloat rates Safe that aren't on FR33THY's keep-list.</summary>
    [RelayCommand]
    public void SelectRecommended()
    {
        if (_imageApps is null) { ListNote = "Read the image's apps first."; return; }
        var rec = IsoPlan.Recommended(_imageApps, _engine.Loaded.Tweaks.Select(t => (t.Id, (string?)t.Risk.ToString(), t.Keep))).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var i in List("Apps").Items) i.IsChecked = rec.Contains(i.Value);
    }

    [RelayCommand]
    public void ClearLists()
    {
        foreach (var i in Lists.SelectMany(l => l.Items)) i.IsChecked = false;
    }

    // ---- 7 AkariOS

    [ObservableProperty]
    public partial bool AkariOS { get; set; } = true;

    public bool AkariOSEnabled { get; } = true;

    public string AkariOSNote { get; } = "";

    public bool HasAkariOSNote => AkariOSNote.Length > 0;

    // ---- Build

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasBuildError))]
    public partial string BuildError { get; private set; } = "";

    public bool HasBuildError => BuildError.Length > 0;

    /// <summary>The ISO built ("" = none yet): the page offers its folder.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasResult))]
    public partial string ResultPath { get; private set; } = "";

    public bool HasResult => ResultPath.Length > 0;

    [RelayCommand]
    public void OpenOutFolder() => _open.Folder(OutDir.Trim());

    /// <summary>Build ISO (the Review step's Next): the answer file made, asked, then the Create ISO step with its
    /// stages following the build; done = the result and a toast with Open folder.</summary>
    [RelayCommand]
    public async Task BuildAsync()
    {
        BuildError = "";
        ResultPath = "";
        if (Edition is not { } ed) { BuildError = "Open the ISO and pick an edition first (Windows image)."; return; }
        if (_tools.Build is not { } build) return;
        byte[]? answer = null;
        try
        {
            if (Answer == "Local") answer = UnattendFile.Make(IsoPlan.AnswerFields(_unattend.Start(), User, Password, SkipOobe));
            else if (Answer == "Generator")
            {
                var (bytes, error) = await _unattend.IsoAnswerAsync();
                if (bytes is null)
                {
                    if (error is not null) BuildError = $"The Unattend Generator's choices have a problem: {error}";
                    return;
                }
                answer = bytes;
            }
        }
        catch (UnattendException e) { BuildError = $"The answer file could not be made: {e.Message}"; return; }
        var choices = Choices(ed, answer);
        var name = IsoPlan.OutName(choices.Iso);
        var what = IsCustom ? $"{PlanText}, {RemovalCount} apps and features picked from the image" : $"{CurrentMode!.Name}: {PlanText}";
        var q = $"Build {name} from {ed.Name}?\n\n{what}. It takes 20 to 40 minutes and AkariOS can't be used meanwhile.";
        if (!await _dialogs.ConfirmAsync("Build the ISO?", q, "Build ISO")) return;
        StartStages(IsoPlan.Steps(choices, PickedGroups));
        var progress = new PostedProgress(_background, p =>
        {
            if (_busy is { } b) _shell.Report(b, p);
            ReportStage(p.Done, p.Total);
        });
        var ops = new PostedOps(_background, ReportOperation);
        ResultDetails = "";
        var started = await StartAsync("IsoBuild", $"Building {name}", () =>
        {
            try { return build.Build(choices, progress, ops); }
            catch (Exception e) { return new IsoResult(false, null, e.Message); }
        }, r =>
        {
            if (r is IsoResult { Ok: true, Path: { } path })
            {
                EndStages(true, ((IsoResult)r).Report);
                ResultPath = path;
                _image = "";
                ResetLists();
                _editions = [];
                Editions = [];
                EditionIndex = -1;
                OpenNote = "The work folder was removed: open the ISO again to build another.";
                _shell.Toast("Your ISO is ready", path, InfoBarSeverity.Success, "Open folder", OpenOutFolder);
            }
            else
            {
                EndStages(false, (r as IsoResult)?.Report);
                var why = (r as IsoResult)?.Message ?? "see the log";
                BuildError = $"Not built: {why}";
                _shell.Toast("ISO not built", why, InfoBarSeverity.Error);
            }
            UpdateWizard();
        });
        if (!started) return;
        Step = BuildStep;
        UpdateWizard();
    }

    /// <summary>The image's lists' ticks, counted for the question and Review.</summary>
    public int RemovalCount => Lists.Sum(l => l.Ticked().Length);

    // the wizard's choices: the picked groups (never zISO's always-on data), the image's own lists in Custom only, the
    // AkariOS mode's bake and first sign-in
    private IsoChoices Choices(IsoEdition ed, byte[]? answer)
    {
        var lists = Lists.ToDictionary(l => l.Kind, l => IsCustom ? l.Ticked() : []);
        var groups = PickedGroups;
        var build = BuildOf(ed.Version);
        var exe = AkariOS ? _tools.AkariExe : null;
        return new IsoChoices
        {
            OutDir = OutDir.Trim(), Iso = IsoPath.Trim(), Image = _image, Index = ed.Index, Edition = ed.Name,
            Apps = lists["Apps"], Capabilities = lists["Capabilities"], Features = lists["Features"], Packages = lists["Packages"],
            AkariExe = exe, Unattend = answer, Settings = Settings,
            Groups = [.. groups.Select(g => g.Id)],
            AppPatterns = [.. IsoWizard.AppPatterns(groups, _engine.Loaded.Tweaks.Select(t => (t.Id, (string?)t.Risk.ToString(), t.Keep)))],
            Bake = BakeFor(build)?.InImage, FirstSignIn = IsAkariOSMode && FirstSignIn && exe is not null, ImageBuild = build,
        };
    }
}