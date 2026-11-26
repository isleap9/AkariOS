using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>A startup entry's row (New-AkariStartupRow): its switch, Remove, publisher, location, command.</summary>
public sealed partial class StartupRowViewModel : ObservableObject
{
    private readonly Action<StartupRowViewModel, string> _changed;
    private bool _muted;
    private bool _isOn;

    public StartupRowViewModel(StartupItem item, Action<StartupRowViewModel, string> changed)
    {
        Item = item;
        _changed = changed;
    }

    public StartupItem Item { get; set; }
    public string Busy { get; set; } = "";
    public string Error { get; set; } = "";

    public string Key => Item.Key;
    public string Name => Item.Name;
    public string Command => Item.Command;
    public string Location => Item.Location;
    public string Publisher => Item.Publisher;
    public bool HasPublisher => Publisher.Length > 0;

    [ObservableProperty] public partial string StatusText { get; private set; } = "";
    [ObservableProperty] public partial string StateLine { get; private set; } = "";
    [ObservableProperty] public partial bool IsError { get; private set; }
    [ObservableProperty] public partial bool ShowPlainLine { get; private set; }
    [ObservableProperty] public partial bool IsIdle { get; private set; } = true;

    /// <summary>The switch: it starts with Windows (while a change runs, the change asked for).</summary>
    public bool IsOn
    {
        get => _isOn;
        set
        {
            if (!SetProperty(ref _isOn, value) || _muted) return;
            _changed(this, value ? "On" : "Off");
        }
    }

    [RelayCommand]
    private void Remove() => _changed(this, "Remove");

    /// <summary>Set-AkariStartupRow; showing: what the switch shows (the change asked for while it runs).</summary>
    public void Update(bool? showing = null)
    {
        StatusText = Item.Enabled ? "On" : "Off";
        StateLine = Error.Length > 0 ? $"Failed: {Error}" : Busy == "Waiting" ? "Waiting…" : Busy.Length > 0 ? "Applying…" : "";
        IsError = Error.Length > 0;
        ShowPlainLine = StateLine.Length > 0 && !IsError;
        IsIdle = Busy.Length == 0;
        _muted = true;
        try
        {
            var on = showing ?? Item.Enabled;
            _isOn = !on;
            IsOn = on;
        }
        finally { _muted = false; }
    }
}

/// <summary>
/// The Startup apps page's list (src/UI/StartupPage.ps1; Optimize › Tools › Startup, under oneclick-startup-cleanup):
/// every app that starts with Windows from the Run keys and the Startup folders; filters, its own search, the count,
/// Refresh; each row's switch turns it on or off right away (Task Manager's StartupApproved value) and Remove deletes
/// it after asking, both through the Catalogue's queue (the restore point first). Read once in the background, the
/// rows kept.
/// </summary>
public sealed partial class StartupListViewModel(Engine engine, IBackground background, IDialogService dialogs, CatalogueViewModel catalogue, ActivityLog activity)
    : ObservableObject
{
    private readonly Dictionary<string, StartupRowViewModel> _rows = [];
    private IReadOnlyList<StartupItem>? _list;
    private string _readError = "";
    private bool _reading;

    public IReadOnlyDictionary<string, StartupRowViewModel> Rows => _rows;

    public static IReadOnlyList<ChoiceItem> Filters { get; } = StartupLists.Filters.Select(f => new ChoiceItem(StartupLists.FilterLabel(f), f)).ToList();

    /// <summary>For binding (a static member doesn't bind).</summary>
    public IReadOnlyList<ChoiceItem> FilterChoices => Filters;

    [ObservableProperty] public partial IReadOnlyList<StartupRowViewModel> Shown { get; private set; } = [];
    [ObservableProperty] public partial string CountText { get; private set; } = "";
    [ObservableProperty] public partial string Message { get; private set; } = "";
    [ObservableProperty] public partial bool HasMessage { get; private set; }

    [ObservableProperty] public partial string Filter { get; set; } = "All";
    [ObservableProperty] public partial string Query { get; set; } = "";

    partial void OnFilterChanged(string value) => Fill();
    partial void OnQueryChanged(string value) => Fill();

    /// <summary>The entries' reader and writer, on the engine's registry and the real user's folders.</summary>
    private StartupItems Items() => new(engine.Registry, StartupItems.Locations(engine.Registry, engine.Services));

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
        CountText = "Reading the startup apps…";
        background.Run(() =>
        {
            try { return Items().All(); }
            catch (Exception e) { return e; }
        }, r =>
        {
            _reading = false;
            (_list, _readError) = r is IReadOnlyList<StartupItem> l ? (l, "") : ([], (r as Exception)?.Message ?? "");
            Fill();
        });
    }

    private void Fill()
    {
        if (_list is null || _reading) return;
        if (_readError.Length > 0)
        {
            (Shown, CountText) = ([], "");
            SetMessage($"Couldn't read the startup apps: {_readError}");
            return;
        }
        var view = StartupLists.View(_list, Filter, Query);
        CountText = StartupLists.CountText(_list, view);
        var rows = new List<StartupRowViewModel>();
        foreach (var i in view)
        {
            if (!_rows.TryGetValue(i.Key, out var row))
                _rows[i.Key] = row = new StartupRowViewModel(i, (r, a) => background.Post(() => _ = ChangeAsync(r, a)));
            else if (row.Busy.Length == 0) row.Item = i;
            row.Update();
            rows.Add(row);
        }
        Shown = rows;
        SetMessage(view.Count > 0 ? "" : _list.Count > 0 ? "No startup app matches." : "Nothing starts with Windows from the Run keys or the Startup folders.");
    }

    private void SetMessage(string m) => (Message, HasMessage) = (m, m.Length > 0);

    private sealed record Done(string Error, IReadOnlyList<StartupItem>? List);

    /// <summary>The question Remove asks (Invoke-AkariStartupChange's).</summary>
    public static string RemoveQuestion(StartupItem i) =>
        $"- Its {(i.Kind == "Registry" ? "registry value" : "Startup folder shortcut")} is deleted: {i.Command}\n- The app itself stays installed\n- To keep it and only stop it starting, turn it off instead";

    /// <summary>Invoke-AkariStartupChange: On, Off or Remove (asks first) through the Catalogue's queue, the list read
    /// again after.</summary>
    public async Task ChangeAsync(StartupRowViewModel r, string action)
    {
        if (r.Busy.Length > 0) { r.Update(); return; }
        if (action == "Remove" && !await dialogs.ConfirmAsync($"Remove \"{r.Name}\" from the startup apps?", RemoveQuestion(r.Item), "Remove", "Cancel"))
            return;
        r.Error = "";
        r.Busy = "Waiting";
        bool? showing = action == "Remove" ? null : action == "On";
        r.Update(showing);
        var item = r.Item;
        var verb = action switch { "On" => "turn on", "Off" => "turn off", _ => "remove" };
        catalogue.Enqueue($"{item.Name}: {verb}", restore: true,
            () => { r.Busy = "Running"; r.Update(showing); },
            () =>
            {
                var error = "";
                var items = Items();
                try
                {
                    if (action == "Remove") items.Remove(item);
                    else items.SetEnabled(item, action == "On", engine.Services.UtcNow());
                }
                catch (Exception e) when (e is InvalidOperationException or IOException or UnauthorizedAccessException or System.Security.SecurityException)
                {
                    error = e.Message;
                    engine.Log.Write($"Failed: {e.Message}");
                }
                IReadOnlyList<StartupItem>? now = null;
                try { now = items.All(); } catch (Exception) { }
                return new Done(error, now);
            },
            res =>
            {
                r.Busy = "";
                if (res is not Done d) { r.Update(); return; }
                r.Error = d.Error;
                if (d.List is { } list) _list = list;
                var found = _list?.FirstOrDefault(x => x.Key == r.Key);
                if (found is not null) r.Item = found;
                if (action == "Remove" && d.Error.Length == 0 && found is null)
                {
                    _rows.Remove(r.Key);
                    activity.Add($"Removed startup app \"{item.Name}\"", "Optimize", 1, "Startup");
                    Fill();
                    return;
                }
                r.Update();
            });
    }
}
