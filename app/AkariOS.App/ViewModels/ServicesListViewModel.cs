using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>A service's row (New-AkariServiceRow): its startup type dropdown, Start / Stop, status, the Windows default,
/// what FR33THY / ZOICWARE set, the State line.</summary>
public sealed partial class ServiceRowViewModel : ObservableObject
{
    private readonly Action<ServiceRowViewModel, string, string> _changed;
    private bool _muted;
    private object? _selectedStart;

    public ServiceRowViewModel(ServiceInfo info, Action<ServiceRowViewModel, string, string> changed)
    {
        Info = info;
        _changed = changed;
    }

    public ServiceInfo Info { get; set; }
    public string Busy { get; set; } = "";
    public string Error { get; set; } = "";

    public string Name => Info.Name;
    public string DisplayName => Info.DisplayName;
    public string Description => Info.Description;
    public bool HasDescription => Description.Length > 0;

    public static IReadOnlyList<ChoiceItem> StartChoices { get; } = ServiceLists.StartTypes.Select(p => new ChoiceItem(p.Value, p.Key)).ToList();
    public IReadOnlyList<ChoiceItem> Choices => StartChoices;

    [ObservableProperty] public partial string StatusText { get; private set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; private set; }
    [ObservableProperty] public partial bool IsStopped { get; private set; }
    /// <summary>The Windows default is known and the startup type is it.</summary>
    [ObservableProperty] public partial bool IsDefault { get; private set; }
    [ObservableProperty] public partial bool ShowPlainLine { get; private set; }
    [ObservableProperty] public partial string DefaultText { get; private set; } = "";
    /// <summary>The startup type differs from the Windows default.</summary>
    [ObservableProperty] public partial bool IsChanged { get; private set; }
    [ObservableProperty] public partial string SuggestText { get; private set; } = "";
    [ObservableProperty] public partial bool HasSuggest { get; private set; }
    [ObservableProperty] public partial string StateLine { get; private set; } = "";
    [ObservableProperty] public partial bool HasStateLine { get; private set; }
    [ObservableProperty] public partial bool IsError { get; private set; }
    /// <summary>Start or Stop, or "" when neither (a service that can't stop).</summary>
    [ObservableProperty] public partial string ActionText { get; private set; } = "";
    [ObservableProperty] public partial bool HasAction { get; private set; }
    [ObservableProperty] public partial bool CanChangeStart { get; private set; }
    [ObservableProperty] public partial bool IsIdle { get; private set; } = true;

    /// <summary>The startup type dropdown (a <see cref="ChoiceItem"/> whose Value is the start type).</summary>
    public object? SelectedStart
    {
        get => _selectedStart;
        set
        {
            if (!SetProperty(ref _selectedStart, value) || _muted || value is not ChoiceItem { Value: string v }) return;
            if (v != Info.Start) _changed(this, "StartType", v);
        }
    }

    [RelayCommand]
    private void Act() => _changed(this, "Control", ActionText);

    /// <summary>Set-AkariServiceRow.</summary>
    public void Update(IReadOnlyDictionary<string, int>? defaults, IReadOnlyDictionary<string, IReadOnlyList<string>>? suggest)
    {
        StatusText = Info.Status.Length > 0 ? Info.Status : "Unknown";
        IsRunning = Info.Status == "Running";
        IsStopped = !IsRunning;
        var def = defaults is null ? null : ServiceLists.Default(Info, defaults);
        DefaultText = def is { } d ? $"Windows default: {ServiceLists.StartLabel(d)}" : "";
        IsChanged = defaults is not null && ServiceLists.Changed(Info, defaults);
        IsDefault = DefaultText.Length > 0 && !IsChanged;
        var sug = suggest is null ? [] : ServiceLists.Suggestion(Info, suggest);
        SuggestText = sug.Count > 0 ? "Suggested: " + string.Join(", ", sug) : "";
        HasSuggest = sug.Count > 0;
        StateLine = Error.Length > 0 ? $"Failed: {Error}" : Busy == "Waiting" ? "Waiting…" : Busy.Length > 0 ? "Applying…" : "";
        HasStateLine = StateLine.Length > 0;
        IsError = Error.Length > 0;
        ShowPlainLine = HasStateLine && !IsError;
        ActionText = ServiceLists.Action(Info);
        HasAction = ActionText.Length > 0;
        IsIdle = Busy.Length == 0;
        // Boot / System start: a driver-like service Windows' console doesn't change either
        CanChangeStart = IsIdle && ServiceLists.IsStartType(Info.Start);
        _muted = true;
        try
        {
            _selectedStart = this;
            SelectedStart = StartChoices.FirstOrDefault(i => i.Value as string == Info.Start);
        }
        finally { _muted = false; }
    }
}

/// <summary>
/// The Services page's list (src/UI/ServicesPage.ps1), under its Category's Tweaks: by default the services FR33THY
/// and ZOICWARE change (services.psd1, each with what their picks set), "Show all" every service as in Windows'
/// Services console; filters, its own search, the count, Refresh; each row's startup type and Start / Stop act right
/// away through the Catalogue's queue (the restore point first). Disabling or stopping a service Windows needs asks
/// first. Read once in the background, the rows kept.
/// </summary>
public sealed partial class ServicesListViewModel(Engine engine, IBackground background, IDialogService dialogs, CatalogueViewModel catalogue) : ObservableObject
{
    private readonly Dictionary<string, ServiceRowViewModel> _rows = [];
    private IReadOnlyList<ServiceInfo>? _list;
    private string _readError = "";
    private bool _reading;
    private IReadOnlyDictionary<string, int>? _defaults;
    private IReadOnlyDictionary<string, IReadOnlyList<string>>? _suggest;

    public IReadOnlyDictionary<string, ServiceRowViewModel> Rows => _rows;

    /// <summary>The filters ($AkariServiceFilters), "Changed" shown as "Not default".</summary>
    public static IReadOnlyList<ChoiceItem> Filters { get; } = ServiceLists.Filters.Select(f => new ChoiceItem(f == "Changed" ? "Not default" : f, f)).ToList();

    /// <summary>For binding (a static member doesn't bind).</summary>
    public IReadOnlyList<ChoiceItem> FilterChoices => Filters;

    [ObservableProperty] public partial IReadOnlyList<ServiceRowViewModel> Shown { get; private set; } = [];
    [ObservableProperty] public partial string CountText { get; private set; } = "";
    [ObservableProperty] public partial string Message { get; private set; } = "";
    [ObservableProperty] public partial bool HasMessage { get; private set; }

    [ObservableProperty] public partial string Filter { get; set; } = "All";
    [ObservableProperty] public partial bool ShowAll { get; set; }
    [ObservableProperty] public partial string Query { get; set; } = "";

    partial void OnFilterChanged(string value) => Fill();
    partial void OnShowAllChanged(bool value) => Fill();
    partial void OnQueryChanged(string value) => Fill();

    private IServiceManager? Manager => engine.Services.Services;

    /// <summary>The page shows the list: read the first time.</summary>
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
        CountText = "Reading the services…";
        background.Run(() =>
        {
            try { return Manager?.All() ?? throw new NotSupportedException("this engine can't read services"); }
            catch (Exception e) { return e; }
        }, r =>
        {
            _reading = false;
            (_list, _readError) = r is IReadOnlyList<ServiceInfo> l ? (l, "") : ([], (r as Exception)?.Message ?? "");
            Fill();
        });
    }

    private void Fill()
    {
        if (_list is null || _reading) return;
        if (_readError.Length > 0)
        {
            (Shown, CountText) = ([], "");
            SetMessage($"Couldn't read the services: {_readError}");
            return;
        }
        _defaults ??= ServiceLists.Defaults(engine.Files);
        _suggest ??= ServiceLists.Suggestions(engine.Files);
        var view = ServiceLists.View(_list, Filter, Query.Trim(), _defaults, ShowAll ? null : _suggest);
        CountText = ShowAll ? (view.Count == _list.Count ? $"{_list.Count} services" : $"{view.Count} of {_list.Count} services")
            : $"{view.Count} services FR33THY and ZOICWARE change";
        var rows = new List<ServiceRowViewModel>();
        foreach (var svc in view)
        {
            if (!_rows.TryGetValue(svc.Name, out var row)) _rows[svc.Name] = row = new ServiceRowViewModel(svc, (r, op, v) => background.Post(() => _ = ChangeAsync(r, op, v)));
            else if (row.Busy.Length == 0) row.Info = svc;
            row.Update(_defaults, _suggest);
            rows.Add(row);
        }
        Shown = rows;
        SetMessage(view.Count == 0 ? "No service matches." : "");
    }

    private void SetMessage(string m) => (Message, HasMessage) = (m, m.Length > 0);

    private sealed record Done(string Error, ServiceInfo? Info);

    /// <summary>Invoke-AkariServiceChange: op StartType (a startup type) or Control (Start / Stop), through the
    /// Catalogue's queue, the service read back after.</summary>
    public async Task ChangeAsync(ServiceRowViewModel r, string op, string value)
    {
        if (r.Busy.Length > 0 || value.Length == 0) return;
        var q = ServiceLists.Confirm(r.Info, op, value);
        if (q.Length > 0 && !await dialogs.ConfirmAsync(r.DisplayName, q, "Continue", "Cancel")) { r.Update(_defaults, _suggest); return; }
        r.Error = "";
        r.Busy = "Waiting";
        r.Update(_defaults, _suggest);
        var name = r.Info.Name;
        var label = op == "StartType"
            ? $"{r.Info.DisplayName}: startup type {ServiceLists.StartTypes.First(p => p.Key == value).Value}"
            : $"{r.Info.DisplayName}: {value.ToLowerInvariant()}";
        catalogue.Enqueue(label, restore: true, () => { r.Busy = "Running"; r.Update(_defaults, _suggest); }, () =>
        {
            var error = "";
            try
            {
                if (op == "StartType") ServiceStart.Set(engine.Registry, name, value);
                else (Manager ?? throw new NotSupportedException("this engine can't start or stop services")).Control(name, value);
            }
            catch (Exception e)
            {
                error = e.Message;
                engine.Log.Write($"Failed: {e.Message}");
            }
            ServiceInfo? now = null;
            try { now = Manager?.One(name); } catch (Exception) { }
            return new Done(error, now);
        }, res =>
        {
            r.Busy = "";
            if (res is Done d)
            {
                r.Error = d.Error;
                if (d.Info is { } info)
                {
                    r.Info = info;
                    if (_list is not null) _list = _list.Select(x => x.Name == name ? info : x).ToList();
                }
            }
            r.Update(_defaults, _suggest);
        });
    }
}
