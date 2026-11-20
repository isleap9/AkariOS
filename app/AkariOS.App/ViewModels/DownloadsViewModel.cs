using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Apps;
using AkariOS.Core.Data;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.ViewModels;

public enum CardState { None, Waiting, Installing, Installed, Failed }

/// <summary>
/// A Downloads card (New-AkariAppCard -Mode Action): the icon, name and category, a Caution install's mark, and its
/// action by State (Set-AkariAppCardState): Install, Waiting / Installing, Installed (Uninstall from its menu when
/// winget installed it), Failed (the reason; Install again).
/// </summary>
public sealed partial class AppCardViewModel(Tweak tweak, AppIcon icon, DownloadsViewModel owner) : ObservableObject
{
    public Tweak Tweak { get; } = tweak;
    public AppIcon Icon { get; } = icon;
    public string Name => Tweak.Name;
    public string Category => AppLists.DownloadCategory(Tweak);
    public string Tip => $"{Tweak.Description}\n{AppLists.Source(Tweak)}".Trim();
    public bool IsCaution => AppLists.InstallMark(Tweak) is not null;
    public string CautionTip => AppLists.InstallMark(Tweak)?.Tip ?? "";

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CanInstall), nameof(IsBusy), nameof(IsInstalled), nameof(IsFailed), nameof(BusyText), nameof(CanUninstall))]
    public partial CardState State { get; set; }

    [ObservableProperty]
    public partial string Why { get; set; } = "";

    public bool CanInstall => State == CardState.None;
    public bool IsBusy => State is CardState.Waiting or CardState.Installing;
    public bool IsInstalled => State == CardState.Installed;
    public bool IsFailed => State == CardState.Failed;
    public string BusyText => State.ToString();

    /// <summary>winutil W4's Uninstall, one app at a time: an installed app winget can remove here.</summary>
    public bool CanUninstall => IsInstalled && Tweak.Winget.Count > 0 && string.IsNullOrEmpty(Tweak.RemoveWith);

    [RelayCommand]
    private void Install() => owner.Add(Tweak.Id);

    [RelayCommand]
    private Task Uninstall() => owner.UninstallAsync(this);
}

/// <summary>
/// Downloads (Apps.ps1's Show-AkariDownloads, winutil W4): a SelectorBar of categories, a search box, Update all apps,
/// then a grid of app cards whose Install acts right away: queued, installed one at a time (a Run of that one app, no
/// restore point). Which apps are on this PC is read once a session, quietly. One per app.
/// </summary>
public sealed partial class DownloadsViewModel : ObservableObject
{
    private readonly Engine _engine;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly ShellState _shell;
    private readonly ActivityLog _activity;
    private readonly AppIcons _icons;
    private readonly Dictionary<string, AppCardViewModel> _cards = [];
    private readonly List<string> _queue = [];
    private string? _installing;
    private BusyWork? _busy;
    // installs done since the queue was last empty: the busy toast's "n of m"
    private int _batch;
    private string _query = "";
    private string _category = "All";
    private bool _installedRead;

    public DownloadsViewModel(Engine engine, IBackground background, IDialogService dialogs, ShellState shell, ActivityLog activity, AppIcons icons)
    {
        (_engine, _background, _dialogs, _shell, _activity, _icons) = (engine, background, dialogs, shell, activity, icons);
        var n = AppLists.Install(engine.Loaded.Tweaks, engine.System).Count;
        Lead = $"Apps, game launchers, runtimes and tools, installed from winget where possible. {n} in the catalogue.";
        // a Run of Install AkariOS or Remove apps is done: the installs that waited for it start
        _shell.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ShellState.Locked) && !_shell.Locked) Next();
        };
    }

    public string Lead { get; }

    /// <summary>All, then $AkariDownloadCategories.</summary>
    public IReadOnlyList<string> Categories { get; } = ["All", .. AppLists.DownloadCategories.Select(c => c.Key)];

    [ObservableProperty]
    public partial bool IsReading { get; private set; }

    /// <summary>The cards of the category and search.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsEmpty))]
    public partial IReadOnlyList<AppCardViewModel> Shown { get; private set; } = [];

    [ObservableProperty]
    public partial string EmptyText { get; private set; } = "";

    public bool IsEmpty => !IsReading && Shown.Count == 0 && _cards.Count > 0;

    /// <summary>Every card by Tweak id.</summary>
    public IReadOnlyDictionary<string, AppCardViewModel> Cards => _cards;

    public string Category
    {
        get => _category;
        set
        {
            if (SetProperty(ref _category, value ?? "All")) Filter();
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

    /// <summary>The page was opened: the cards are read (once), then which apps are on this PC (once a session).</summary>
    public void Open()
    {
        if (_cards.Count > 0 || IsReading) { ReadInstalled(); return; }
        IsReading = true;
        _background.Run(() =>
        {
            IReadOnlyList<string> appx = [];
            IReadOnlyDictionary<string, string> logos = new Dictionary<string, string>();
            if (_engine.Services.Apps is { } apps)
            {
                try
                {
                    var all = apps.All();
                    appx = all.Select(p => p.Name).ToList();
                    logos = AppPackages.Logos(all);
                }
                catch (Exception e) { _engine.Log.Write($"Warning: the Store apps could not be read ({e.Message})"); }
            }
            var items = AppLists.Downloads(_engine.Loaded.Tweaks, _engine.System, appx);
            return items.Select(i => new AppCardViewModel(i.Tweak, _icons.Of(i.Tweak, logos), this)).ToList();
        }, r =>
        {
            foreach (var c in r as List<AppCardViewModel> ?? [])
            {
                if (_queue.Contains(c.Tweak.Id)) c.State = CardState.Waiting;
                _cards[c.Tweak.Id] = c;
            }
            IsReading = false;
            Filter();
            ReadInstalled();
        });
    }

    // Start-AkariInstalledRead: one "winget list" and the other apps' Detects, in the background; the page stays usable
    private void ReadInstalled()
    {
        if (_installedRead || _cards.Count == 0) return;
        _installedRead = true;
        var installs = _cards.Values.Select(c => c.Tweak).Where(t => t.Group is null).ToList();
        _background.Run(() =>
        {
            try { return AppKinds.InstalledApps(installs, _engine.Context); }
            catch (Exception e) { _engine.Log.Write($"Warning: the installed apps could not be read ({e.Message})"); return null; }
        }, r =>
        {
            foreach (var id in r as IReadOnlyList<string> ?? [])
                if (_cards.TryGetValue(id, out var c) && c.State == CardState.None) c.State = CardState.Installed;
        });
    }

    // Set-AkariDownloadsFilter
    private void Filter()
    {
        var q = _query.Trim();
        Shown = _cards.Values.Where(c => (_category == "All" || c.Category == _category) && (q.Length == 0 || PsSemantics.Like(c.Name, $"*{q}*"))).ToList();
        EmptyText = q.Length > 0 ? $"No apps match \"{q}\"" : "No apps here";
    }

    // ---- installs: one at a time

    /// <summary>Add-AkariInstall: queued; the next one starts when nothing else is changing the PC.</summary>
    public void Add(string id)
    {
        if (_queue.Contains(id)) return;
        _queue.Add(id);
        if (_cards.TryGetValue(id, out var c)) { c.State = CardState.Waiting; c.Why = ""; }
        Next();
        // one more behind the running install: the busy toast counts it
        if (_installing is not null && _busy is { } b && _batch + _queue.Count > 1) _shell.Report(b, _batch, _batch + _queue.Count);
    }

    /// <summary>An install is waiting or running.</summary>
    public bool Busy => _installing is not null || _queue.Count > 0;

    /// <summary>Installs waiting in the queue (not the one running).</summary>
    public int Waiting => _queue.Count - (_installing is null ? 0 : 1);

    // Start-AkariInstallNext
    private void Next()
    {
        if (_installing is not null || _queue.Count == 0 || _shell.Locked) return;
        var id = _queue[0];
        if (_engine.Find(id) is not { } t) { _queue.RemoveAt(0); Next(); return; }
        _installing = id;
        if (_cards.TryGetValue(id, out var c)) c.State = CardState.Installing;
        var label = $"Installing {t.Name}";
        _busy = _shell.Begin(label);
        // more than one queued: "Installing PuTTY (2 of 3)"
        var total = _batch + _queue.Count;
        if (total > 1) _shell.Report(_busy, _batch, total);
        _engine.Log.Write(label);
        _background.Run(() =>
        {
            try { return _engine.Runner.Run([new PlanItem(id, TweakMode.Apply)], _engine.Find).FirstOrDefault(); }
            catch (Exception e) { _engine.Log.WriteFile($"Error: install {id}: {e}"); return null; }
        }, r => Installed(t, r as Outcome));
    }

    // Complete-AkariInstall: the card says how, the next one starts
    private void Installed(Tweak t, Outcome? o)
    {
        _installing = null;
        _queue.Remove(t.Id);
        _shell.End(_busy);
        _batch = _queue.Count == 0 ? 0 : _batch + 1;
        var card = _cards.GetValueOrDefault(t.Id);
        if (o is { Kind: OutcomeKind.Applied or OutcomeKind.Already })
        {
            if (card is not null) card.State = CardState.Installed;
            _activity.Add($"Installed {t.Name}", "Downloads", 1, "download");
            _shell.Toast($"{t.Name} is installed", o.Reboot ? "Restart Windows to finish." : "");
        }
        else
        {
            var why = o is { Message.Length: > 0 } ? o.Message : "The install did not run. The details are in akari.log.";
            if (card is not null) (card.Why, card.State) = (why, CardState.Failed);
            _shell.Toast($"{t.Name} was not installed", why, InfoBarSeverity.Error);
        }
        Next();
    }

    // ---- winutil W4: Uninstall (an installed card's menu) and Update all apps

    /// <summary>Start-AkariUninstall for one app: asked with Get-AkariUninstallText, then uninstalled in the background.</summary>
    public async Task UninstallAsync(AppCardViewModel card)
    {
        if (!card.CanUninstall || _shell.IsBusy) return;
        var (text, count) = Selection.UninstallText([card.Tweak]);
        if (count == 0) { await _dialogs.ShowInfoAsync("Uninstall", text); return; }
        if (!await _dialogs.ConfirmAsync("Uninstall", text, "Uninstall")) return;
        var busy = _shell.Begin($"Uninstalling {card.Name}");
        var done = new TaskCompletionSource<object?>();
        _background.Run(() =>
        {
            try { return AppKinds.Uninstall(card.Tweak, _engine.Context); }
            catch (Exception e) { return new Outcome(card.Tweak.Id, TweakMode.Revert, OutcomeKind.Failed, false, e.Message); }
        }, r => done.SetResult(r));
        var o = await done.Task as Outcome;
        _shell.End(busy);
        if (o is { Kind: OutcomeKind.Reverted or OutcomeKind.Already })
        {
            card.State = CardState.None;
            if (o.Kind == OutcomeKind.Reverted) _activity.Add($"Uninstalled {card.Name}", "Downloads", 1, "trash-2");
            _shell.Toast($"{card.Name} is uninstalled", o.Reboot ? "Restart Windows to finish." : "");
        }
        else _shell.Toast($"{card.Name} was not uninstalled", o?.Message is { Length: > 0 } m ? m : "The details are in akari.log.", InfoBarSeverity.Error);
        Next();
    }

    /// <summary>Start-AkariUpdateApps: the Tools Tweak tools-update-apps (one "winget upgrade --all"), asked first.</summary>
    [RelayCommand]
    public async Task UpdateAllAsync()
    {
        if (_engine.Find("tools-update-apps") is not { } t || _shell.IsBusy || Busy) return;
        if (!string.IsNullOrEmpty(t.Confirm) && !await _dialogs.ConfirmAsync(t.Name, t.Confirm, "Update all")) return;
        var busy = _shell.Begin("Updating all apps");
        var done = new TaskCompletionSource<object?>();
        _background.Run(() =>
        {
            try { return _engine.Runner.Run([new PlanItem(t.Id, TweakMode.Apply)], _engine.Find).FirstOrDefault(); }
            catch (Exception e) { return new Outcome(t.Id, TweakMode.Apply, OutcomeKind.Failed, false, e.Message); }
        }, r => done.SetResult(r));
        var o = await done.Task as Outcome;
        _shell.End(busy);
        if (o is { Kind: OutcomeKind.Failed } || o is null)
            _shell.Toast("Apps not updated", o?.Message is { Length: > 0 } m ? m : "The details are in akari.log.", InfoBarSeverity.Error);
        else _shell.Toast("Apps updated", o.Message.Length > 0 ? o.Message : "Every app winget knows is up to date.");
        _installedRead = false;
        ReadInstalled();
    }
}
