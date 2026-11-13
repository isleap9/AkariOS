using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>A service's row: its card, startup type dropdown, Start / Stop button and State line.</summary>
public sealed class ServiceRow
{
    public required ServiceInfo Info { get; set; }
    public required Border Card { get; init; }
    public required ComboBox Combo { get; init; }
    public required Button Button { get; init; }
    public required TextBlock Status { get; init; }
    public required TextBlock Default { get; init; }
    public required TextBlock Suggest { get; init; }
    public required TextBlock StateLine { get; init; }
    public string Busy { get; set; } = "";
    public string Error { get; set; } = "";
    internal bool Muted { get; set; }
}

/// <summary>
/// The Services page's list (src/UI/ServicesPage.ps1), under its Category's Tweaks: by default the services FR33THY
/// and ZOICWARE change (services.psd1, each with what their picks set), "Show all" every service as in Windows'
/// Services console; filters, the count, Refresh; each row with its startup type and Start / Stop, acting right away
/// through the Catalogue's queue (the restore point first). Disabling or stopping a service Windows needs asks first.
/// The list is read once in the background; the rows are kept.
/// </summary>
public sealed class ServicesList(AppServices s, CatalogueView catalogue)
{
    private readonly StackPanel _host = new();
    private readonly StackPanel _rowsPanel = new();
    private readonly Dictionary<string, ServiceRow> _rows = [];
    private IReadOnlyList<ServiceInfo>? _list;
    private string _readError = "";
    private bool _reading;
    private string _query = "";
    private string _filter = "All";
    private bool _all;
    private DockPanel? _bar;
    private TextBlock? _count;
    private IReadOnlyDictionary<string, int>? _defaults;
    private IReadOnlyDictionary<string, IReadOnlyList<string>>? _suggest;

    public IReadOnlyDictionary<string, ServiceRow> Rows => _rows;

    /// <summary>The filter ($AkariServiceFilters).</summary>
    public string Filter
    {
        get => _filter;
        set { _filter = value; Fill(); }
    }

    /// <summary>"Show all": every service, not only FR33THY's and ZOICWARE's.</summary>
    public bool ShowAll
    {
        get => _all;
        set { _all = value; Fill(); }
    }

    private IServiceManager? Manager => s.Engine.Services.Services;

    /// <summary>Show-AkariServiceList: the toolbar and the rows (the same element each time), the search filtering
    /// them; the list is read the first time.</summary>
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
        refresh.ToolTip = "Read the services again";
        refresh.Margin = new Thickness(0);
        DockPanel.SetDock(refresh, Dock.Right);
        _bar.Children.Add(refresh);
        var all = BarSwitch("Show all", "Off: only the services FR33THY and ZOICWARE change, the ones known to be safe to turn off. On: every service on this PC, to go further.");
        all.Switch.Click += (_, _) => ShowAll = all.Switch.IsChecked == true;
        DockPanel.SetDock(all.Panel, Dock.Right);
        _bar.Children.Add(all.Panel);
        var seg = new ListBox { Margin = new Thickness(0, 0, 16, 0) };
        seg.SetResourceReference(FrameworkElement.StyleProperty, "Segmented");
        foreach (var f in ServiceLists.Filters)
            seg.Items.Add(new ListBoxItem
            {
                Content = f == "Changed" ? "Not default" : f, Tag = f,
                ToolTip = f == "Changed" ? "Startup types that differ from the Windows default (for the services Akari knows the default of)" : null,
            });
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

    /// <summary>New-AkariBarSwitch: a label and a CatSwitch, for a toolbar.</summary>
    internal static (StackPanel Panel, ToggleButton Switch) BarSwitch(string label, string tip)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(16, 0, 12, 0), ToolTip = tip };
        var lb = Parts.Text(label, 13, "Mu");
        lb.VerticalAlignment = VerticalAlignment.Center;
        lb.Margin = new Thickness(0, 0, 10, 0);
        var sw = new ToggleButton { VerticalAlignment = VerticalAlignment.Center, IsChecked = false };
        sw.SetResourceReference(FrameworkElement.StyleProperty, "CatSwitch");
        sp.Children.Add(lb);
        sp.Children.Add(sw);
        return (sp, sw);
    }

    // Start-AkariServiceRead / Complete-AkariServiceRead
    private void Read()
    {
        _reading = true;
        _rowsPanel.Children.Clear();
        if (_count is not null) _count.Text = "Reading the services…";
        s.Background(() =>
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
        if (_count is null || _list is null || _reading) return;
        _rowsPanel.Children.Clear();
        if (_readError.Length > 0)
        {
            _count.Text = "";
            _rowsPanel.Children.Add(Parts.Text($"Couldn't read the services: {_readError}", 13, "Bad"));
            return;
        }
        _defaults ??= ServiceLists.Defaults(s.Engine.Files);
        _suggest ??= ServiceLists.Suggestions(s.Engine.Files);
        var view = ServiceLists.View(_list, _filter, _query, _defaults, _all ? null : _suggest);
        _count.Text = _all ? (view.Count == _list.Count ? $"{_list.Count} services" : $"{view.Count} of {_list.Count} services")
            : $"{view.Count} services FR33THY and ZOICWARE change";
        foreach (var svc in view)
        {
            if (!_rows.TryGetValue(svc.Name, out var row)) _rows[svc.Name] = row = NewRow(svc);
            else if (row.Busy.Length == 0) row.Info = svc;
            _rowsPanel.Children.Add(row.Card);
            Update(row);
        }
        if (view.Count == 0) _rowsPanel.Children.Add(Parts.Text("No service matches.", 13, "Mu"));
    }

    // New-AkariServiceRow
    private ServiceRow NewRow(ServiceInfo svc)
    {
        var card = new Border { Tag = svc.Name, Padding = new Thickness(18, 10, 18, 10), MinHeight = 0, Margin = new Thickness(0, 0, 0, 4) };
        card.SetResourceReference(FrameworkElement.StyleProperty, "SettingCard");
        var dp = new DockPanel();
        var combo = new ComboBox { Width = 230, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12, 0, 0, 0), ToolTip = "Startup type", Tag = svc.Name };
        combo.SetResourceReference(FrameworkElement.StyleProperty, "Combo");
        foreach (var (k, label) in ServiceLists.StartTypes) combo.Items.Add(new ComboBoxItem { Content = label, Tag = k });
        DockPanel.SetDock(combo, Dock.Right);
        dp.Children.Add(combo);
        var btn = Parts.Button("");
        btn.MinWidth = 76;
        btn.VerticalAlignment = VerticalAlignment.Center;
        btn.Margin = new Thickness(16, 0, 0, 0);
        DockPanel.SetDock(btn, Dock.Right);
        dp.Children.Add(btn);
        var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        var name = Parts.Text(svc.DisplayName, 14);
        name.FontWeight = FontWeights.SemiBold;
        text.Children.Add(name);
        var meta = new WrapPanel { Margin = new Thickness(0, 3, 0, 0) };
        var id = Parts.Text(svc.Name, 12, "Ter");
        id.SetResourceReference(TextBlock.FontFamilyProperty, "FontMono");
        id.Margin = new Thickness(0, 0, 12, 0);
        var status = Parts.Text("", 12, "Ter");
        status.Margin = new Thickness(0, 0, 12, 0);
        var def = Parts.Text("", 12, "Ter");
        foreach (var x in new[] { id, status, def }) { x.VerticalAlignment = VerticalAlignment.Center; meta.Children.Add(x); }
        text.Children.Add(meta);
        if (svc.Description.Length > 0)
        {
            var d = Parts.Text(svc.Description, 12, "Mu");
            d.Margin = new Thickness(0, 4, 0, 0);
            d.MaxHeight = 34;
            d.TextTrimming = TextTrimming.CharacterEllipsis;
            d.ToolTip = svc.Description;
            text.Children.Add(d);
        }
        var suggest = Parts.Text("", 12, "Ter");
        suggest.Margin = new Thickness(0, 4, 0, 0);
        text.Children.Add(suggest);
        var state = Parts.Text("", 12, "Ter");
        state.Margin = new Thickness(0, 4, 0, 0);
        text.Children.Add(state);
        dp.Children.Add(text);
        card.Child = dp;
        var row = new ServiceRow { Info = svc, Card = card, Combo = combo, Button = btn, Status = status, Default = def, Suggest = suggest, StateLine = state };
        combo.SelectionChanged += (_, _) =>
        {
            if (row.Muted || combo.SelectedItem is not ComboBoxItem { Tag: string v }) return;
            if (v != row.Info.Start) Change(row, "StartType", v);
        };
        btn.Click += (_, _) => Change(row, "Control", btn.Content as string ?? "");
        return row;
    }

    // Set-AkariServiceRow
    private void Update(ServiceRow r)
    {
        var svc = r.Info;
        r.Status.Text = svc.Status.Length > 0 ? svc.Status : "Unknown";
        r.Status.SetResourceReference(TextBlock.ForegroundProperty, svc.Status == "Running" ? "Ok" : "Ter");
        var def = _defaults is null ? null : ServiceLists.Default(svc, _defaults);
        r.Default.Text = def is { } d ? $"Windows default: {ServiceLists.StartLabel(d)}" : "";
        r.Default.SetResourceReference(TextBlock.ForegroundProperty, _defaults is not null && ServiceLists.Changed(svc, _defaults) ? "Warn" : "Ter");
        var sug = _suggest is null ? [] : ServiceLists.Suggestion(svc, _suggest);
        r.Suggest.Text = sug.Count > 0 ? "Suggested: " + string.Join(", ", sug) : "";
        r.Suggest.Visibility = sug.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        r.StateLine.Text = r.Error.Length > 0 ? $"Failed: {r.Error}" : r.Busy == "Waiting" ? "Waiting…" : r.Busy.Length > 0 ? "Applying…" : "";
        r.StateLine.SetResourceReference(TextBlock.ForegroundProperty, r.Error.Length > 0 ? "Bad" : "Ter");
        r.StateLine.Visibility = r.StateLine.Text.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        var act = ServiceLists.Action(svc);
        r.Button.Content = act;
        r.Button.Visibility = act.Length > 0 ? Visibility.Visible : Visibility.Hidden;
        // Boot / System start: a driver-like service Windows' console doesn't change either
        r.Combo.IsEnabled = r.Busy.Length == 0 && ServiceLists.IsStartType(svc.Start);
        r.Button.IsEnabled = r.Busy.Length == 0;
        r.Muted = true;
        try { r.Combo.SelectedItem = r.Combo.Items.OfType<ComboBoxItem>().FirstOrDefault(i => i.Tag as string == svc.Start); }
        finally { r.Muted = false; }
    }

    private sealed record Done(string Error, ServiceInfo? Info);

    // Invoke-AkariServiceChange / Start-AkariServiceJob / Complete-AkariServiceJob: op StartType (a startup type) or
    // Control (Start / Stop); through the Catalogue's queue, the service read back after
    private void Change(ServiceRow r, string op, string value)
    {
        if (r.Busy.Length > 0 || value.Length == 0) return;
        if (catalogue.IsoBusy()) { Update(r); return; }
        var q = ServiceLists.Confirm(r.Info, op, value);
        if (q.Length > 0 && s.Dialogs?.Confirm(q, "Continue", "Cancel", "Warning") != true) { Update(r); return; }
        r.Error = "";
        r.Busy = "Waiting";
        Update(r);
        var name = r.Info.Name;
        var label = op == "StartType"
            ? $"{r.Info.DisplayName}: startup type {ServiceLists.StartTypes.First(p => p.Key == value).Value}"
            : $"{r.Info.DisplayName}: {value.ToLowerInvariant()}";
        catalogue.Enqueue(label, restore: true, () => { r.Busy = "Running"; Update(r); }, () =>
        {
            var error = "";
            try
            {
                if (op == "StartType") ServiceStart.Set(s.Engine.Registry, name, value);
                else (Manager ?? throw new NotSupportedException("this engine can't start or stop services")).Control(name, value);
            }
            catch (Exception e)
            {
                error = e.Message;
                s.Log.Write($"Failed: {e.Message}");
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
            Update(r);
        });
    }
}
