using System.Collections.ObjectModel;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml;

namespace AkariOS.App.ViewModels;

/// <summary>
/// A row of the Apps step (New-AkariAppRow): its Tweak or Entry, on the PC or not, a checkbox; a removal's Risk mark
/// (Recommended / Optional / Not recommended), an install's Caution mark; the name, description and source.
/// </summary>
public sealed partial class AppRowViewModel(AppItem item, Action<AppRowViewModel> changed) : ObservableObject
{
    private bool _isChecked;

    public Tweak Tweak { get; } = item.Tweak;
    public bool Installed { get; } = item.Installed;
    public bool Removal => AppLists.IsRemoval(Tweak);
    public string Name => Tweak.Name;
    public string Description => string.IsNullOrEmpty(Tweak.Description) ? "Not in Akari's list: found on this PC" : Tweak.Description;
    public string Source => AppLists.Source(Tweak);
    public string SourceTip => Installed ? Source : $"{Source} (not on this PC)";
    public string NameTip => Tweak.Keep ? "Kept by the AkariOS pick (FR33THY's keep-list)" : Tweak.Name;
    public double Dim => Installed ? 1 : 0.6;

    public bool IsSafe => Removal && Tweak.Risk == Risk.Safe;
    public bool IsOptional => Removal && Tweak.Risk == Risk.Caution;
    public bool IsRisky => Removal && Tweak.Risk == Risk.Advanced;
    public bool IsCautionInstall => AppLists.InstallMark(Tweak) is not null;
    public string CautionTip => AppLists.InstallMark(Tweak)?.Tip ?? "";

    /// <summary>Muted: set by a pick, no question asked.</summary>
    internal bool Muted { get; set; }

    public bool IsChecked
    {
        get => _isChecked;
        set
        {
            if (SetProperty(ref _isChecked, value) && !Muted) changed(this);
        }
    }

    [ObservableProperty]
    public partial Visibility Shows { get; set; } = Visibility.Visible;
}

/// <summary>A table of the Apps step: its name, count, rows and a note (reading, nothing to restore, not read).</summary>
public sealed partial class AppTableViewModel(string name, string last) : ObservableObject
{
    public string Name { get; } = name;

    /// <summary>The last column's heading: App ID, Capability, Feature, Id, Source.</summary>
    public string Last { get; } = last;

    public ObservableCollection<AppRowViewModel> Rows { get; } = [];

    [ObservableProperty]
    public partial string Title { get; set; } = name;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasNote))]
    public partial string Note { get; set; } = "";

    public bool HasNote => Note.Length > 0;

    public void Add(IEnumerable<AppRowViewModel> rows)
    {
        foreach (var r in rows) Rows.Add(r);
        Title = $"{Name} ({Rows.Count})";
    }
}

/// <summary>
/// The Apps step (src/UI/Apps.ps1, after Win11Debloat's App Removal page): Remove (Store apps, Optional features, Windows
/// features read once the tab shows, legacy apps; Select recommended, AkariOS, Clear selection, Only installed) and
/// Install (a card per kind of app, then the Store apps the debloat removed). Rows write into the Selection; nothing
/// runs until Review &amp; Apply. W5 adds Downloads' and Remove apps' own pages, icons and buttons on it.
/// </summary>
public sealed partial class AppsStepViewModel : ObservableObject
{
    private readonly Engine _engine;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly IDictionary<string, Pending> _sel;
    private readonly Action _changed;
    private readonly Dictionary<string, AppRowViewModel> _rows = [];
    private Func<Tweak, bool>? _pick;
    private (Preset Preset, IReadOnlyList<string> Ids)? _pendingPick;
    private bool _onlyInstalled = true;
    private string _query = "";
    private AppTableViewModel? _caps, _feats;

    public AppsStepViewModel(Engine engine, IBackground background, IDialogService dialogs, IDictionary<string, Pending> sel, Action changed)
    {
        (_engine, _background, _dialogs, _sel, _changed) = (engine, background, dialogs, sel, changed);
    }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsBuilt))]
    public partial bool IsReading { get; private set; }

    public bool IsBuilt => !IsReading && RemoveTables.Count > 0;

    /// <summary>The tab shown: Remove or Install.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsRemoveTab), nameof(IsInstallTab))]
    public partial string Tab { get; private set; } = "Remove";

    public bool IsRemoveTab => Tab == "Remove";
    public bool IsInstallTab => Tab == "Install";

    /// <summary>The feature lists were asked for (once, when the Remove tab first shows).</summary>
    public bool FeaturesRead { get; private set; }

    public ObservableCollection<AppTableViewModel> RemoveTables { get; } = [];
    public ObservableCollection<AppTableViewModel> InstallTables { get; } = [];

    /// <summary>The rows by Tweak id.</summary>
    public IReadOnlyDictionary<string, AppRowViewModel> Rows => _rows;

    [ObservableProperty]
    public partial string StatusText { get; private set; } = "0 to remove, 0 to install";

    /// <summary>"Only installed": rows of apps not on this PC are hidden.</summary>
    public bool OnlyInstalled
    {
        get => _onlyInstalled;
        set
        {
            if (SetProperty(ref _onlyInstalled, value)) Filter();
        }
    }

    public string Query
    {
        get => _query;
        set
        {
            if (SetProperty(ref _query, value ?? "")) Filter();
        }
    }

    private sealed record ReadResult(IReadOnlyList<string> Installed, IReadOnlyList<string> Appx, IReadOnlyList<AppItem> Legacy);

    /// <summary>Reads the PC's apps (once), then builds the tables.</summary>
    public void Ensure()
    {
        if (IsReading || RemoveTables.Count > 0) return;
        IsReading = true;
        _background.Run(Read, r =>
        {
            Build(r as ReadResult ?? new ReadResult([], [], []));
            IsReading = false;
            if (_pendingPick is { } p) { _pendingPick = null; QuickSelect(p.Preset, p.Ids); }
            if (IsRemoveTab) ShowTab("Remove");
        });
    }

    // one package read (the removable ones, every name for the restore card) and the legacy apps' Detects
    private ReadResult Read()
    {
        IReadOnlyList<string> installed = [], appx = [];
        if (_engine.Services.Apps is { } apps)
        {
            try
            {
                var all = apps.All();
                installed = apps.Installed(all);
                appx = all.Select(p => p.Name).ToList();
            }
            catch (Exception e) { _engine.Log.Write($"Warning: the Store apps could not be read ({e.Message})"); }
        }
        var legacy = _engine.Loaded.Tweaks
            .Where(t => t.Section == "Apps" && t.Category == "Remove" && t.Group is null && (t.Requires.Count == 0 || Requirements.Check(t, _engine.System) is null))
            .OrderBy(t => t.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(t => new AppItem(t, !Gone(t))).ToList();
        return new ReadResult(installed, appx, legacy);
    }

    // Get-AkariLegacyRemoveList: installed = its Detect says not gone yet
    private bool Gone(Tweak t)
    {
        try { return t.Code is { } c && t.Blocks.Contains("Detect") && c.Detect(t, _engine.Context) == TweakState.Optimized; }
        catch (Exception) { return false; }
    }

    private AppRowViewModel Row(AppItem item) => _rows[item.Tweak.Id] = new AppRowViewModel(item, r => _background.Post(() => _ = StepAsync(r)));

    private void Build(ReadResult r)
    {
        var store = new AppTableViewModel("Store apps", "App ID");
        store.Add(AppLists.Store(_engine.Loaded.Tweaks, _engine.Loaded.Groups, r.Installed).Select(Row));
        _caps = new AppTableViewModel("Optional features", "Capability") { Note = "Reading what is on this PC..." };
        _feats = new AppTableViewModel("Windows features", "Feature") { Note = "Reading what is on this PC..." };
        var legacy = new AppTableViewModel("Legacy apps", "Id");
        legacy.Add(r.Legacy.Select(Row));
        foreach (var t in new[] { store, _caps, _feats, legacy }) RemoveTables.Add(t);
        foreach (var c in AppLists.InstallCards(_engine.Loaded.Tweaks, _engine.System, r.Appx))
        {
            var t = new AppTableViewModel(c.Title, "Source");
            if (c.Items.Count == 0) t.Note = "Nothing to restore: every app in this list is on this PC.";
            t.Add(c.Items.Select(Row));
            InstallTables.Add(t);
        }
        Filter();
        UpdateStatus();
    }

    [RelayCommand]
    public void ShowTab(string tab)
    {
        Tab = tab;
        if (tab == "Remove" && !FeaturesRead && _caps is not null) ReadFeatures();
    }

    // Start-AkariFeatureRead / Complete-AkariFeatureRead
    private void ReadFeatures()
    {
        FeaturesRead = true;
        _background.Run(() =>
        {
            if (_engine.Services.Apps is not { } apps) return null;
            try { return (apps.InstalledCapabilities(), apps.EnabledFeatures()); }
            catch (Exception e) { _engine.Log.Write($"Warning: the features could not be read ({e.Message})"); return null; }
        }, r =>
        {
            var (caps, feats) = r is ValueTuple<IReadOnlyList<string>, IReadOnlyList<string>> x ? x : ([], []);
            foreach (var (table, kind, names) in new[] { (_caps!, EntryKind.CapabilityRemove, caps), (_feats!, EntryKind.FeatureDisable, feats) })
            {
                table.Note = r is null ? "Could not be read here." : "";
                var rows = AppLists.Found(_engine.Loaded.Groups, kind, names).Select(Row).ToList();
                table.Add(rows);
                // the last quick pick, applied to the rows that arrived after it
                if (_pick is { } pick) Pick(pick, rows);
            }
            Filter();
            UpdateStatus();
        });
    }

    // Step-AkariAppCheck: checked = Remove or Install (an Advanced one asks first), unchecked = no change
    private async Task StepAsync(AppRowViewModel r)
    {
        var next = r.IsChecked ? Selection.Optimized : Selection.None;
        if (Selection.ConfirmText(r.Tweak, next, null) is { } q && !await _dialogs.ConfirmAsync(r.Tweak.Name, q, "Continue")) Set(r, false);
        else Selection.SetPending(_sel, r.Tweak, TweakState.Unknown, next, null, null);
        UpdateStatus();
    }

    private void Set(AppRowViewModel r, bool on)
    {
        r.Muted = true;
        try { r.IsChecked = on; } finally { r.Muted = false; }
        Selection.SetPending(_sel, r.Tweak, TweakState.Unknown, on ? Selection.Optimized : Selection.None, null, null);
    }

    // Select-AkariApps: the removals on this PC the pick says yes to are checked, every other one unchecked (no
    // question: Review lists them all); remembered, so features read later get it too
    private void Pick(Func<Tweak, bool> pick)
    {
        _pick = pick;
        Pick(pick, _rows.Values.Where(r => r.Removal).ToList());
        UpdateStatus();
    }

    private void Pick(Func<Tweak, bool> pick, IEnumerable<AppRowViewModel> rows)
    {
        foreach (var r in rows) Set(r, r.Installed && pick(r.Tweak));
    }

    [RelayCommand]
    private void SelectRecommended() => Pick(AppLists.Recommended);

    [RelayCommand]
    private void SelectAkariOS() => Pick(AppLists.AkariOSPick);

    [RelayCommand]
    private void ClearRemovals() => Pick(_ => false);

    [RelayCommand]
    private void ClearInstalls()
    {
        foreach (var r in _rows.Values.Where(r => !r.Removal)) Set(r, false);
        UpdateStatus();
    }

    /// <summary>Set-AkariQuickSelect's apps: every row unchecked, then a preset's removals (its "&lt;group&gt;/*"
    /// Groups but their Keep Entries, and the ids it resolved to) and installs checked; waits for the read.</summary>
    public void QuickSelect(Preset preset, IReadOnlyList<string> resolvedIds)
    {
        Ensure();
        if (IsReading) { _pendingPick = (preset, resolvedIds); return; }
        foreach (var r in _rows.Values) Set(r, false);
        var pick = AppLists.PresetPick(preset.Entries.Select(e => e.Id), resolvedIds);
        _pick = pick;
        Pick(pick, _rows.Values.Where(r => r.Removal));
        var ids = resolvedIds.ToHashSet(StringComparer.Ordinal);
        foreach (var r in _rows.Values.Where(r => !r.Removal && ids.Contains(r.Tweak.Id))) Set(r, true);
        UpdateStatus();
    }

    /// <summary>The picks to remove and to install.</summary>
    public (int Remove, int Install) Counts()
    {
        var on = _rows.Values.Where(r => r.IsChecked).ToList();
        var rm = on.Count(r => r.Removal);
        return (rm, on.Count - rm);
    }

    private void UpdateStatus()
    {
        var (rm, inst) = Counts();
        StatusText = $"{rm} to remove, {inst} to install";
        _changed();
    }

    // Set-AkariAppsFilter: the filter and Only installed hide the rows that don't match
    private void Filter()
    {
        var q = _query.Trim();
        foreach (var r in _rows.Values)
        {
            var t = r.Tweak;
            var hit = q.Length == 0 || PsSemantics.Like($"{t.Name} {t.Description} {AppLists.Source(t)}", $"*{q}*");
            if (_onlyInstalled && r.Removal && !r.Installed) hit = false;
            r.Shows = hit ? Visibility.Visible : Visibility.Collapsed;
        }
    }
}
