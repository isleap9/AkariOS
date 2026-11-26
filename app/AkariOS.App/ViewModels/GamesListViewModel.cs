using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Machine;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>One of a game's three switches (GPU, Fullscreen optimizations off, High CPU priority).</summary>
public sealed partial class GameSwitchViewModel(GameRowViewModel row, string setting, string label, string tip) : ObservableObject
{
    private bool _isOn;
    internal bool Muted;

    public string Setting { get; } = setting;
    public string Label { get; } = label;
    public string Tip { get; } = tip;

    [ObservableProperty] public partial bool IsIdle { get; set; } = true;

    public bool IsOn
    {
        get => _isOn;
        set
        {
            if (!SetProperty(ref _isOn, value) || Muted) return;
            row.Changed(this, value);
        }
    }

    internal void Show(bool on)
    {
        Muted = true;
        try { _isOn = !on; IsOn = on; } finally { Muted = false; }
    }
}

/// <summary>A game's row (New-AkariGameRow): its name, source and exe, three switches, Remove from list for an added one.</summary>
public sealed partial class GameRowViewModel : ObservableObject
{
    private readonly Action<GameRowViewModel, GameSwitchViewModel, bool> _changed;
    private readonly Action<GameRowViewModel> _remove;

    /// <summary>$AkariGameSwitches.</summary>
    public static readonly (string Setting, string Label, string Tip)[] Switches =
    [
        ("Gpu", "High-performance GPU", "Windows runs it on the high-performance graphics card (Settings › Display › Graphics). Off: Windows decides."),
        ("Fso", "Fullscreen optimizations off", "Exclusive fullscreen as the game asks, without Windows' fullscreen optimizations (Compatibility tab). Off: Windows' default."),
        ("Priority", "High CPU priority", "The game starts at High CPU priority. It applies to every program with this exe's name. Off: Normal."),
    ];

    public GameRowViewModel(GameInfo game, Action<GameRowViewModel, GameSwitchViewModel, bool> changed, Action<GameRowViewModel> remove)
    {
        Game = game;
        (_changed, _remove) = (changed, remove);
        Items = Switches.Select(s => new GameSwitchViewModel(this, s.Setting, s.Label, s.Tip)).ToList();
    }

    public GameInfo Game { get; set; }
    public string Busy { get; set; } = "";
    public string Error { get; set; } = "";

    public string Key => Game.Key;
    public string Name => Game.Name;
    public string Meta => $"{Game.Source}  {Game.Exe}";
    public string Exe => Game.Exe;
    public bool IsAdded => Game.Source == "Added";
    public IReadOnlyList<GameSwitchViewModel> Items { get; }

    [ObservableProperty] public partial string StateLine { get; private set; } = "";
    [ObservableProperty] public partial bool IsError { get; private set; }
    [ObservableProperty] public partial bool ShowPlainLine { get; private set; }

    internal void Changed(GameSwitchViewModel s, bool on) => _changed(this, s, on);

    [RelayCommand]
    private void Remove() => _remove(this);

    public GameSwitchViewModel Switch(string setting) => Items.First(i => i.Setting == setting);

    /// <summary>Set-AkariGameRow; showing: a switch's change asked for while it runs.</summary>
    public void Update((string Setting, bool On)? showing = null)
    {
        foreach (var s in Items)
        {
            s.Show(showing is { } x && x.Setting == s.Setting ? x.On : Game.Get(s.Setting));
            s.IsIdle = Busy.Length == 0;
        }
        StateLine = Error.Length > 0 ? $"Failed: {Error}" : Busy == "Waiting" ? "Waiting…" : Busy.Length > 0 ? "Applying…" : "";
        IsError = Error.Length > 0;
        ShowPlainLine = StateLine.Length > 0 && !IsError;
    }
}

/// <summary>
/// Per-game settings (src/UI/GamesPage.ps1; under Optimize › Gaming's Tweaks): the games found (Steam, Epic, GOG, added
/// by hand), three switches each acting right away through the Catalogue's queue (the restore point first); Add a game…
/// picks an exe (games.json). Read once in the background (Refresh reads them again), the rows kept.
/// </summary>
public sealed partial class GamesListViewModel(Engine engine, IBackground background, IFilePicker picker, CatalogueViewModel catalogue, Games? games = null)
    : ObservableObject
{
    private readonly Dictionary<string, GameRowViewModel> _rows = [];
    private IReadOnlyList<GameInfo>? _list;
    private string _readError = "";
    private bool _reading;

    /// <summary>The games' reader and writer: the real launchers' places and the app's games.json, unless a test gives one.</summary>
    public Games Games { get; } = games ?? new Games(engine.Registry,
        Games.Live(engine.Registry, engine.Services, Path.Combine(AkariPaths.UserFolder, "games.json")));

    public IReadOnlyDictionary<string, GameRowViewModel> Rows => _rows;

    [ObservableProperty] public partial IReadOnlyList<GameRowViewModel> Shown { get; private set; } = [];
    [ObservableProperty] public partial string CountText { get; private set; } = "";
    [ObservableProperty] public partial string Message { get; private set; } = "";
    [ObservableProperty] public partial bool HasMessage { get; private set; }
    [ObservableProperty] public partial string Query { get; set; } = "";

    partial void OnQueryChanged(string value) => Fill();

    public void Show()
    {
        if (_list is null && !_reading) Read(); else Fill();
    }

    [RelayCommand]
    public void Refresh()
    {
        if (!_reading) Read();
    }

    private void Read()
    {
        _reading = true;
        Shown = [];
        CountText = "Looking for games…";
        background.Run(() =>
        {
            try { return Games.All(); }
            catch (Exception e) { return e; }
        }, r =>
        {
            _reading = false;
            (_list, _readError) = r is IReadOnlyList<GameInfo> l ? (l, "") : ([], (r as Exception)?.Message ?? "");
            Fill();
        });
    }

    /// <summary>Get-AkariGameView and Get-AkariGameCountText.</summary>
    public static IReadOnlyList<GameInfo> View(IEnumerable<GameInfo> games, string query)
    {
        var q = query.Trim();
        return games.Where(g => q.Length == 0 || $"{g.Name} {g.Exe} {g.Source}".Contains(q, StringComparison.OrdinalIgnoreCase)).ToList();
    }

    public static string Count(int all, int shown) => shown == all ? $"{all} {(all == 1 ? "game" : "games")} found" : $"{shown} of {all} {(all == 1 ? "game" : "games")}";

    private void Fill()
    {
        if (_list is null || _reading) return;
        if (_readError.Length > 0)
        {
            (Shown, CountText) = ([], "");
            SetMessage($"Couldn't look for games: {_readError}");
            return;
        }
        var view = View(_list, Query);
        CountText = Count(_list.Count, view.Count);
        var rows = new List<GameRowViewModel>();
        foreach (var g in view)
        {
            if (!_rows.TryGetValue(g.Key, out var row))
                _rows[g.Key] = row = new GameRowViewModel(g, (r, s, on) => background.Post(() => Change(r, s.Setting, on)), r => background.Post(() => RemoveOwn(r)));
            else if (row.Busy.Length == 0) row.Game = g;
            row.Update();
            rows.Add(row);
        }
        Shown = rows;
        SetMessage(view.Count > 0 ? "" : _list.Count > 0 ? "No game matches." : "No Steam, Epic or GOG games found. Add a game to set it up.");
    }

    private void SetMessage(string m) => (Message, HasMessage) = (m, m.Length > 0);

    /// <summary>Add-AkariOwnGame: an exe picked, kept in games.json, the list read again.</summary>
    [RelayCommand]
    public async Task AddAsync()
    {
        if (await picker.OpenExeAsync() is not { } exe) return;
        var own = Games.Own().ToList();
        if (!own.Any(g => string.Equals(g.Exe, exe, StringComparison.OrdinalIgnoreCase)))
        {
            own.Add(new OwnGame(Path.GetFileNameWithoutExtension(exe), exe));
            Games.SaveOwn(own);
            engine.Log.Write($"Game added: {exe}");
        }
        Read();
    }

    private void RemoveOwn(GameRowViewModel r)
    {
        Games.SaveOwn(Games.Own().Where(g => !string.Equals(g.Exe, r.Exe, StringComparison.OrdinalIgnoreCase)));
        _rows.Remove(r.Key);
        Read();
    }

    private sealed record Done(string Error, (bool Gpu, bool Fso, bool Priority)? Now);

    /// <summary>Invoke-AkariGameChange: one switch through the Catalogue's queue, read back after.</summary>
    public void Change(GameRowViewModel r, string setting, bool on)
    {
        if (r.Busy.Length > 0) { r.Update(); return; }
        r.Error = "";
        r.Busy = "Waiting";
        r.Update((setting, on));
        var exe = r.Exe;
        var label = GameRowViewModel.Switches.First(s => s.Setting == setting).Label;
        catalogue.Enqueue($"{r.Name}: {label} {(on ? "on" : "off")}", restore: true,
            () => { r.Busy = "Running"; r.Update((setting, on)); },
            () =>
            {
                var error = "";
                try { Games.Set(exe, setting, on); }
                catch (Exception e) when (e is InvalidOperationException or IOException or UnauthorizedAccessException or System.Security.SecurityException)
                {
                    error = e.Message;
                    engine.Log.Write($"Failed: {e.Message}");
                }
                (bool, bool, bool)? now = null;
                try { now = Games.SettingsOf(exe); } catch (Exception) { }
                return new Done(error, now);
            },
            res =>
            {
                r.Busy = "";
                if (res is Done d)
                {
                    r.Error = d.Error;
                    if (d.Now is { } n) r.Game = r.Game with { Gpu = n.Gpu, Fso = n.Fso, Priority = n.Priority };
                }
                r.Update();
            });
    }
}
