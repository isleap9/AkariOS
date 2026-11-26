using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Presets;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.ViewModels;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>
/// The hero's facts (Start-AkariHomeStats), one per app: Tweaks (the Catalogue's), removable apps (Store apps on this
/// PC outside the keep-list), changes applied (what Export would save). The last two are read in the background once,
/// "applied" again after a change; "—" until read.
/// </summary>
public sealed partial class HomeStats : ObservableObject
{
    private readonly Engine _engine;
    private readonly IBackground _background;
    private readonly CatalogueViewModel _catalogue;
    private bool _appsRead;
    private bool _appliedRead;

    public HomeStats(Engine engine, IBackground background, CatalogueViewModel catalogue)
    {
        (_engine, _background, _catalogue) = (engine, background, catalogue);
        catalogue.Applied += () => _appliedRead = false;
    }

    public int Tweaks => _catalogue.Tweaks.Count;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(AppsText))]
    public partial int? RemovableApps { get; private set; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(AppliedText))]
    public partial int? Applied { get; private set; }

    public string TweaksText => $"{Tweaks}";
    public string AppsText => RemovableApps?.ToString(System.Globalization.CultureInfo.InvariantCulture) ?? "—";
    public string AppliedText => Applied?.ToString(System.Globalization.CultureInfo.InvariantCulture) ?? "—";

    /// <summary>A Run changed the PC: both counts are read again when Home shows.</summary>
    public void Stale() => (_appsRead, _appliedRead) = (false, false);

    /// <summary>Reads what isn't read yet (Home shows it).</summary>
    public void Refresh()
    {
        if (!_appsRead)
        {
            _appsRead = true;
            _background.Run(ReadApps, r => RemovableApps = r as int?);
        }
        if (!_appliedRead)
        {
            _appliedRead = true;
            _background.Run(() =>
            {
                try { return PresetStore.ExportItems(_engine.Loaded.Tweaks, _engine.States, _engine.System).Count; }
                catch (Exception e) { _engine.Log.WriteFile($"Warning: the applied changes could not be read ({e.Message})"); return null; }
            }, r => Applied = r as int?);
        }
    }

    // the removable Store apps on this PC whose Entry isn't on the keep-list (what the AkariOS pick removes)
    private object? ReadApps()
    {
        if (_engine.Services.Apps is not { } apps) return null;
        try { return apps.Installed().Count(n => Loader.ResolveEntry(_engine.Loaded.Groups, $"appx/{n}") is { Keep: false }); }
        catch (Exception e) { _engine.Log.WriteFile($"Warning: the Store apps could not be read ({e.Message})"); return null; }
    }
}

/// <summary>A Recent activity row: its title, "when · where", the count, a glyph.</summary>
public sealed record ActivityItem(string Title, string Detail, string CountText, string Glyph);

/// <summary>A "Since AkariOS" row on Home (X6): the number's name, before → after.</summary>
public sealed record SinceRow(string Name, string Text);

/// <summary>
/// Home (Pages.ps1's Show-AkariHome): the update InfoBar, the hero (headline, Start One-click, Choose changes, the
/// facts), Get started tiles, Quick settings (four AkariOS Tweaks as the Catalogue's own cards, acting right away) and
/// Recent activity.
/// </summary>
public sealed partial class HomeViewModel : ViewModelBase, INavigationAware
{
    /// <summary>$AkariQuickSettings.</summary>
    public static IReadOnlyList<string> QuickIds { get; } = ["disable-game-dvr", "gaming-game-mode", "performance-background-apps-off", "privacy-ads"];

    private readonly IShellNavigator _shell;
    private readonly CatalogueViewModel _catalogue;
    private readonly ActivityLog _activity;
    private readonly Func<DateTime> _now;
    private readonly InstallViewModel _install;

    public HomeViewModel(IShellNavigator shell, CatalogueViewModel catalogue, HomeStats stats, UpdateService updates, ActivityLog activity, InstallViewModel install,
        DriftCheck? drift = null, MetricsAfter? metrics = null)
        : this(shell, catalogue, stats, updates, activity, install, () => DateTime.Now, drift, metrics) { }

    public HomeViewModel(IShellNavigator shell, CatalogueViewModel catalogue, HomeStats stats, UpdateService updates, ActivityLog activity, InstallViewModel install, Func<DateTime> now,
        DriftCheck? drift = null, MetricsAfter? metrics = null)
    {
        (_shell, _catalogue, Stats, Updates, _activity, _install, _now, Drift, _metrics) = (shell, catalogue, stats, updates, activity, install, now, drift, metrics);
        var tweaks = catalogue.Tweaks.ToDictionary(t => t.Id);
        QuickSettings = QuickIds.Where(tweaks.ContainsKey).Select(id => catalogue.Card(tweaks[id])).ToList();
        Title = "Home";
    }

    public HomeStats Stats { get; }

    public UpdateService Updates { get; }

    /// <summary>The drift check (X3): its InfoBar shows while settings went back and it isn't dismissed.</summary>
    public DriftCheck? Drift { get; }

    private readonly MetricsAfter? _metrics;

    /// <summary>X6: "Since AkariOS", the numbers before the last Run and after its restart (Metrics.Diff).</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasSince))]
    public partial IReadOnlyList<SinceRow> SinceRows { get; private set; } = [];

    [ObservableProperty] public partial string SinceNote { get; private set; } = "";

    public bool HasSince => SinceRows.Count > 0;

    private void ReadSince()
    {
        var r = _metrics?.Shown();
        SinceRows = r is null ? [] : Core.Machine.Metrics.Diff(r.Metrics.GetValueOrDefault("Before"), r.Metrics.GetValueOrDefault("After")).Select(x => new SinceRow(x.Name, x.Text)).ToList();
        SinceNote = r is null ? "" : $"Before \"{r.Name}\" and after its restart. These numbers change from one boot to the next: read them as a rough guide.";
    }

    public bool DriftBarOpen => Drift?.Found == true;
    public string DriftTitle => Drift?.Title ?? "";
    public string DriftMessage => DriftCheck.Message;

    public string Overline => $"AkariOS {AkariInfo.Version}";
    public string Headline => "Windows, tuned for games";
    public string Lead => "Debloat and optimize Windows 10 and 11 in one go, or pick each change yourself. Every Toggle and Choice goes back to Windows' default.";

    public IReadOnlyList<TweakCardViewModel> QuickSettings { get; }
    public bool HasQuickSettings => QuickSettings.Count > 0;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasActivity), nameof(HasNoActivity))]
    public partial IReadOnlyList<ActivityItem> Activity { get; private set; } = [];

    public bool HasActivity => Activity.Count > 0;
    public bool HasNoActivity => Activity.Count == 0;

    /// <summary>The update InfoBar: a newer release, not dismissed this session.</summary>
    [ObservableProperty]
    public partial bool UpdateBarOpen { get; private set; }

    /// <summary>Its text: why it can't install now (Blocked), else none.</summary>
    public string UpdateBarText => Updates.Status?.Kind == Core.Update.UpdateKind.Blocked ? Updates.Status.Message : "";

    public void OnNavigatedTo(object? parameter)
    {
        Stats.Refresh();
        _catalogue.Highlight([], "");
        _catalogue.ReadStates(QuickSettings.Select(c => c.Tweak));
        Activity = ReadActivity();
        UpdateBar();
        Updates.PropertyChanged += OnUpdates;
        _activity.Added += OnActivity;
        if (Drift is not null) Drift.PropertyChanged += OnDrift;
        OnDrift(null, null);
        ReadSince();
        if (_metrics is not null) _metrics.Changed += ReadSince;
    }

    public void OnNavigatedFrom()
    {
        Updates.PropertyChanged -= OnUpdates;
        _activity.Added -= OnActivity;
        if (Drift is not null) Drift.PropertyChanged -= OnDrift;
        if (_metrics is not null) _metrics.Changed -= ReadSince;
    }

    private void OnDrift(object? s, System.ComponentModel.PropertyChangedEventArgs? e)
    {
        OnPropertyChanged(nameof(DriftBarOpen));
        OnPropertyChanged(nameof(DriftTitle));
    }

    [RelayCommand]
    private void ReviewDrift() => Drift?.Review();

    [RelayCommand]
    private void DismissDrift()
    {
        if (Drift is not null) Drift.Dismissed = true;
    }

    private void OnUpdates(object? s, System.ComponentModel.PropertyChangedEventArgs e) => UpdateBar();
    private void OnActivity() => Activity = ReadActivity();

    private void UpdateBar()
    {
        UpdateBarOpen = Updates.Found && !Updates.Dismissed;
        OnPropertyChanged(nameof(UpdateBarText));
    }

    private IReadOnlyList<ActivityItem> ReadActivity() =>
        _activity.All().Take(5).Select(a => new ActivityItem(a.Title, $"{ActivityLog.WhenText(a.When, _now())} · {a.Where}",
            $"{a.Count} change{(a.Count != 1 ? "s" : "")}", GlyphOf(a.Where))).ToList();

    /// <summary>A Recent activity row's glyph, by where it ran (Segoe Fluent Icons).</summary>
    public static string GlyphOf(string where) => where switch
    {
        "Optimize" => "",
        "Downloads" => "",
        "Remove apps" => "",
        "Install AkariOS" => "",
        _ => "",
    };

    /// <summary>Start One-click: asked, then handed to the console (the window closes).</summary>
    [RelayCommand]
    private Task OneClick() => _install.StartOneClickAsync();

    /// <summary>Choose changes: Install AkariOS on Guided's first step.</summary>
    [RelayCommand]
    private void ChooseChanges()
    {
        _install.Guide();
        _shell.Open("Install AkariOS");
    }

    [RelayCommand]
    private void Optimize() => _shell.Open("Optimize");

    [RelayCommand]
    private Task UpdateNow() => Updates.InstallAsync();

    [RelayCommand]
    private void WhatsNew() => _shell.Open(NavTable.Settings);

    [RelayCommand]
    private void DismissUpdate()
    {
        Updates.Dismissed = true;
        UpdateBar();
    }
}
