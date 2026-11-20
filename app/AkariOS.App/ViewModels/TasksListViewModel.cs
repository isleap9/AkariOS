using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>A scheduled task's row (New-AkariTaskRow): its switch, folder, status, author, who turns it off and why.</summary>
public sealed partial class TaskRowViewModel : ObservableObject
{
    private readonly Action<TaskRowViewModel, bool> _changed;
    private bool _muted;
    private bool _isOn;

    public TaskRowViewModel(TaskInfo info, TaskSuggestion? suggestion, Action<TaskRowViewModel, bool> changed)
    {
        Info = info;
        _changed = changed;
        SuggestText = suggestion is { } s ? $"Turned off by {s.Source} ({s.Note})" : "";
    }

    public TaskInfo Info { get; set; }
    public string Busy { get; set; } = "";
    public string Error { get; set; } = "";

    public string Key => TaskLists.Key(Info);
    public string Name => Info.Name;
    public string Path => Info.Path;
    public string Author => Info.Author;
    public string Description => Info.Description;
    public bool HasDescription => Description.Length > 0;
    public string SuggestText { get; }
    public bool HasSuggest => SuggestText.Length > 0;

    [ObservableProperty] public partial string StatusText { get; private set; } = "";
    [ObservableProperty] public partial string StateLine { get; private set; } = "";
    [ObservableProperty] public partial bool HasStateLine { get; private set; }
    [ObservableProperty] public partial bool IsError { get; private set; }
    [ObservableProperty] public partial bool ShowPlainLine { get; private set; }
    [ObservableProperty] public partial bool IsIdle { get; private set; } = true;

    /// <summary>The switch: the task is enabled (while a change runs, the change asked for).</summary>
    public bool IsOn
    {
        get => _isOn;
        set
        {
            if (!SetProperty(ref _isOn, value) || _muted) return;
            _changed(this, value);
        }
    }

    /// <summary>Set-AkariTaskRow; showing: what the switch shows (the change asked for while it runs).</summary>
    public void Update(bool? showing = null)
    {
        StatusText = Info.State.Length > 0 ? Info.State : "Unknown";
        StateLine = Error.Length > 0 ? $"Failed: {Error}" : Busy == "Waiting" ? "Waiting…" : Busy.Length > 0 ? "Applying…" : "";
        HasStateLine = StateLine.Length > 0;
        IsError = Error.Length > 0;
        ShowPlainLine = HasStateLine && !IsError;
        IsIdle = Busy.Length == 0;
        _muted = true;
        try
        {
            var on = showing ?? Info.Enabled;
            _isOn = !on;
            IsOn = on;
        }
        finally { _muted = false; }
    }
}

/// <summary>
/// The Scheduled tasks page's list (src/UI/TasksPage.ps1): by default the tasks FR33THY and ZOICWARE turn off
/// (tasks.psd1, with who and why), "Show all" every task as in Task Scheduler; filters, its own search, the count,
/// Refresh; each row's switch turns it on or off right away through the Catalogue's queue (as admin, else schtasks as
/// TrustedInstaller; the restore point first). Read once in the background, the rows kept.
/// </summary>
public sealed partial class TasksListViewModel(Engine engine, IBackground background, CatalogueViewModel catalogue) : ObservableObject
{
    private readonly Dictionary<string, TaskRowViewModel> _rows = [];
    private IReadOnlyList<TaskInfo>? _list;
    private string _readError = "";
    private bool _reading;
    private IReadOnlyList<TaskSuggestion>? _suggest;

    public IReadOnlyDictionary<string, TaskRowViewModel> Rows => _rows;

    /// <summary>The filters: Microsoft shown as Windows, Other as Apps.</summary>
    public static IReadOnlyList<ChoiceItem> Filters { get; } =
        TaskLists.Filters.Select(f => new ChoiceItem(f == "Microsoft" ? "Windows" : f == "Other" ? "Apps" : f, f)).ToList();

    /// <summary>For binding (a static member doesn't bind).</summary>
    public IReadOnlyList<ChoiceItem> FilterChoices => Filters;

    [ObservableProperty] public partial IReadOnlyList<TaskRowViewModel> Shown { get; private set; } = [];
    [ObservableProperty] public partial string CountText { get; private set; } = "";
    [ObservableProperty] public partial string Message { get; private set; } = "";
    [ObservableProperty] public partial bool HasMessage { get; private set; }

    [ObservableProperty] public partial string Filter { get; set; } = "All";
    [ObservableProperty] public partial bool ShowAll { get; set; }
    [ObservableProperty] public partial string Query { get; set; } = "";

    partial void OnFilterChanged(string value) => Fill();
    partial void OnShowAllChanged(bool value) => Fill();
    partial void OnQueryChanged(string value) => Fill();

    private ITaskScheduler? Scheduler => engine.Services.Tasks;

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
        CountText = "Reading the scheduled tasks…";
        background.Run(() =>
        {
            try { return Scheduler?.All() ?? throw new NotSupportedException("this engine can't read scheduled tasks"); }
            catch (Exception e) { return e; }
        }, r =>
        {
            _reading = false;
            (_list, _readError) = r is IReadOnlyList<TaskInfo> l ? (l, "") : ([], (r as Exception)?.Message ?? "");
            Fill();
        });
    }

    private void Fill()
    {
        if (_list is null || _reading) return;
        if (_readError.Length > 0)
        {
            (Shown, CountText) = ([], "");
            SetMessage($"Couldn't read the scheduled tasks: {_readError}");
            return;
        }
        _suggest ??= TaskLists.Suggestions(engine.Files);
        var view = TaskLists.View(_list, Filter, Query.Trim(), ShowAll ? null : _suggest);
        CountText = ShowAll ? (view.Count == _list.Count ? $"{_list.Count} tasks" : $"{view.Count} of {_list.Count} tasks")
            : $"{view.Count} tasks FR33THY and ZOICWARE turn off";
        var rows = new List<TaskRowViewModel>();
        foreach (var t in view)
        {
            var key = TaskLists.Key(t);
            if (!_rows.TryGetValue(key, out var row))
                _rows[key] = row = new TaskRowViewModel(t, TaskLists.Suggestion(t, _suggest), (r, on) => background.Post(() => Change(r, on)));
            else if (row.Busy.Length == 0) row.Info = t;
            row.Update();
            rows.Add(row);
        }
        Shown = rows;
        SetMessage(view.Count == 0 ? "No task matches." : "");
    }

    private void SetMessage(string m) => (Message, HasMessage) = (m, m.Length > 0);

    private sealed record Done(string Error, TaskInfo? Info);

    /// <summary>Invoke-AkariTaskChange: turns the task on or off through the Catalogue's queue, read back after.</summary>
    public void Change(TaskRowViewModel r, bool enabled)
    {
        if (r.Busy.Length > 0) { r.Update(); return; }
        r.Error = "";
        r.Busy = "Waiting";
        r.Update(enabled);
        var (path, name) = (r.Info.Path, r.Info.Name);
        catalogue.Enqueue($"{name}: turn {(enabled ? "on" : "off")}", restore: true,
            () => { r.Busy = "Running"; r.Update(enabled); },
            () =>
            {
                var error = "";
                try { TaskSwitch.Set(Scheduler ?? throw new NotSupportedException("this engine can't change scheduled tasks"), engine.Services.Trusted, engine.Services.Windows, path, name, enabled); }
                catch (Exception e)
                {
                    error = e.Message;
                    engine.Log.Write($"Failed: {e.Message}");
                }
                TaskInfo? now = null;
                try { now = Scheduler?.One(path, name); } catch (Exception) { }
                return new Done(error, now);
            },
            res =>
            {
                r.Busy = "";
                if (res is Done d)
                {
                    r.Error = d.Error;
                    if (d.Info is { } info)
                    {
                        r.Info = info;
                        if (_list is not null) _list = _list.Select(x => TaskLists.Key(x) == TaskLists.Key(info) ? info : x).ToList();
                    }
                }
                r.Update();
            });
    }
}
