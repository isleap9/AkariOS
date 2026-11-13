using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>A task's row: its card, on / off switch and State line.</summary>
public sealed class TaskRow
{
    public required TaskInfo Info { get; set; }
    public required Border Card { get; init; }
    public required ToggleButton Switch { get; init; }
    public required TextBlock Status { get; init; }
    public required TextBlock StateLine { get; init; }
    public string Busy { get; set; } = "";
    public string Error { get; set; } = "";
}

/// <summary>
/// The Scheduled tasks page's list (src/UI/TasksPage.ps1), under its Category's Tweaks: by default the tasks FR33THY
/// and ZOICWARE turn off (tasks.psd1, with who and why), "Show all" every task as in Task Scheduler; filters, the
/// count, Refresh; each row with a switch that turns it on or off right away through the Catalogue's queue (as admin,
/// else schtasks as TrustedInstaller; the restore point first). The list is read once in the background.
/// </summary>
public sealed class TasksList(AppServices s, CatalogueView catalogue)
{
    private readonly StackPanel _host = new();
    private readonly StackPanel _rowsPanel = new();
    private readonly Dictionary<string, TaskRow> _rows = [];
    private IReadOnlyList<TaskInfo>? _list;
    private string _readError = "";
    private bool _reading;
    private string _query = "";
    private string _filter = "All";
    private bool _all;
    private DockPanel? _bar;
    private TextBlock? _count;
    private IReadOnlyList<TaskSuggestion>? _suggest;

    /// <summary>The rows by key (Get-AkariTaskKey: folder and name).</summary>
    public IReadOnlyDictionary<string, TaskRow> Rows => _rows;

    public string Filter
    {
        get => _filter;
        set { _filter = value; Fill(); }
    }

    /// <summary>"Show all": every task, not only FR33THY's and ZOICWARE's.</summary>
    public bool ShowAll
    {
        get => _all;
        set { _all = value; Fill(); }
    }

    private ITaskScheduler? Scheduler => s.Engine.Services.Tasks;

    /// <summary>Show-AkariTaskList: the toolbar and the rows (the same element each time), the search filtering them.</summary>
    public UIElement View(string query)
    {
        _query = query;
        if (_bar is null) Build();
        (_host.Parent as Panel)?.Children.Remove(_host);
        if (_list is null) Read(); else Fill();
        return _host;
    }

    private void Build()
    {
        _bar = new DockPanel { Margin = new Thickness(0, 18, 0, 12) };
        var refresh = Parts.Button("Refresh", click: () => { if (!_reading) Read(); });
        refresh.ToolTip = "Read the tasks again";
        refresh.Margin = new Thickness(0);
        DockPanel.SetDock(refresh, Dock.Right);
        _bar.Children.Add(refresh);
        var all = ServicesList.BarSwitch("Show all", "Off: only the tasks FR33THY and ZOICWARE turn off. On: every task on this PC, apps' updaters included.");
        all.Switch.Click += (_, _) => ShowAll = all.Switch.IsChecked == true;
        DockPanel.SetDock(all.Panel, Dock.Right);
        _bar.Children.Add(all.Panel);
        var seg = new ListBox { Margin = new Thickness(0, 0, 16, 0) };
        seg.SetResourceReference(FrameworkElement.StyleProperty, "Segmented");
        foreach (var f in TaskLists.Filters) seg.Items.Add(new ListBoxItem { Content = f == "Microsoft" ? "Windows" : f == "Other" ? "Apps" : f, Tag = f });
        seg.SelectedIndex = 0;
        seg.SelectionChanged += (_, _) => { if (seg.SelectedItem is ListBoxItem { Tag: string f }) Filter = f; };
        DockPanel.SetDock(seg, Dock.Left);
        _bar.Children.Add(seg);
        _count = Parts.Text("", 13, "Mu");
        _count.VerticalAlignment = VerticalAlignment.Center;
        _bar.Children.Add(_count);
        _host.Children.Add(_bar);
        _host.Children.Add(_rowsPanel);
    }

    private void Read()
    {
        _reading = true;
        _rowsPanel.Children.Clear();
        if (_count is not null) _count.Text = "Reading the scheduled tasks…";
        s.Background(() =>
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
        if (_count is null || _list is null || _reading) return;
        _rowsPanel.Children.Clear();
        if (_readError.Length > 0)
        {
            _count.Text = "";
            _rowsPanel.Children.Add(Parts.Text($"Couldn't read the scheduled tasks: {_readError}", 13, "Bad"));
            return;
        }
        _suggest ??= TaskLists.Suggestions(s.Engine.Files);
        var view = TaskLists.View(_list, _filter, _query, _all ? null : _suggest);
        _count.Text = _all ? (view.Count == _list.Count ? $"{_list.Count} tasks" : $"{view.Count} of {_list.Count} tasks")
            : $"{view.Count} tasks FR33THY and ZOICWARE turn off";
        foreach (var t in view)
        {
            var key = TaskLists.Key(t);
            if (!_rows.TryGetValue(key, out var row)) _rows[key] = row = NewRow(t);
            else if (row.Busy.Length == 0) row.Info = t;
            _rowsPanel.Children.Add(row.Card);
            Update(row);
        }
        if (view.Count == 0) _rowsPanel.Children.Add(Parts.Text("No task matches.", 13, "Mu"));
    }

    // New-AkariTaskRow
    private TaskRow NewRow(TaskInfo t)
    {
        var card = new Border { Tag = TaskLists.Key(t), Padding = new Thickness(18, 10, 18, 10), MinHeight = 0, Margin = new Thickness(0, 0, 0, 4) };
        card.SetResourceReference(FrameworkElement.StyleProperty, "SettingCard");
        var dp = new DockPanel();
        var sw = new ToggleButton { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(16, 0, 0, 0), ToolTip = "On: the task runs when its triggers fire. Off: it never runs." };
        sw.SetResourceReference(FrameworkElement.StyleProperty, "CatSwitch");
        DockPanel.SetDock(sw, Dock.Right);
        dp.Children.Add(sw);
        var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        var name = Parts.Text(t.Name, 14);
        name.FontWeight = FontWeights.SemiBold;
        text.Children.Add(name);
        var meta = new WrapPanel { Margin = new Thickness(0, 3, 0, 0) };
        var path = Parts.Text(t.Path, 12, "Ter");
        path.SetResourceReference(TextBlock.FontFamilyProperty, "FontMono");
        path.Margin = new Thickness(0, 0, 12, 0);
        var status = Parts.Text("", 12, "Ter");
        status.Margin = new Thickness(0, 0, 12, 0);
        var items = new List<TextBlock> { path, status };
        if (t.Author.Length > 0) items.Add(Parts.Text(t.Author, 12, "Ter"));
        foreach (var x in items) { x.VerticalAlignment = VerticalAlignment.Center; meta.Children.Add(x); }
        text.Children.Add(meta);
        if (t.Description.Length > 0)
        {
            var d = Parts.Text(t.Description, 12, "Mu");
            d.Margin = new Thickness(0, 4, 0, 0);
            d.MaxHeight = 34;
            d.TextTrimming = TextTrimming.CharacterEllipsis;
            d.ToolTip = t.Description;
            text.Children.Add(d);
        }
        // who turns it off and why (none for the others: Show all)
        if (_suggest is not null && TaskLists.Suggestion(t, _suggest) is { } r)
        {
            var sg = Parts.Text($"Turned off by {r.Source} ({r.Note})", 12, "Ter");
            sg.Margin = new Thickness(0, 4, 0, 0);
            text.Children.Add(sg);
        }
        var state = Parts.Text("", 12, "Ter");
        state.Margin = new Thickness(0, 4, 0, 0);
        text.Children.Add(state);
        dp.Children.Add(text);
        card.Child = dp;
        var row = new TaskRow { Info = t, Card = card, Switch = sw, Status = status, StateLine = state };
        sw.Click += (_, _) => Change(row, sw.IsChecked == true);
        return row;
    }

    // Set-AkariTaskRow
    private static void Update(TaskRow r)
    {
        var t = r.Info;
        r.Status.Text = t.State.Length > 0 ? t.State : "Unknown";
        r.Status.SetResourceReference(TextBlock.ForegroundProperty, t.State == "Running" ? "Ok" : !t.Enabled ? "Warn" : "Ter");
        r.StateLine.Text = r.Error.Length > 0 ? $"Failed: {r.Error}" : r.Busy == "Waiting" ? "Waiting…" : r.Busy.Length > 0 ? "Applying…" : "";
        r.StateLine.SetResourceReference(TextBlock.ForegroundProperty, r.Error.Length > 0 ? "Bad" : "Ter");
        r.StateLine.Visibility = r.StateLine.Text.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        r.Switch.IsEnabled = r.Busy.Length == 0;
        r.Switch.IsChecked = t.Enabled;
    }

    private sealed record Done(string Error, TaskInfo? Info);

    // Invoke-AkariTaskChange / Start-AkariTaskJob / Complete-AkariTaskJob
    private void Change(TaskRow r, bool enabled)
    {
        if (r.Busy.Length > 0) return;
        if (catalogue.IsoBusy()) { Update(r); return; }
        r.Error = "";
        r.Busy = "Waiting";
        Update(r);
        // the switch shows the change asked for until the task is read back
        r.Switch.IsChecked = enabled;
        var (path, name) = (r.Info.Path, r.Info.Name);
        catalogue.Enqueue($"{name}: turn {(enabled ? "on" : "off")}", restore: true,
            () => { r.Busy = "Running"; Update(r); r.Switch.IsChecked = enabled; },
            () =>
            {
                var error = "";
                try { TaskSwitch.Set(Scheduler ?? throw new NotSupportedException("this engine can't change scheduled tasks"), s.Engine.Services.Trusted, s.Engine.Services.Windows, path, name, enabled); }
                catch (Exception e)
                {
                    error = e.Message;
                    s.Log.Write($"Failed: {e.Message}");
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
                Update(r);
            });
    }
}
