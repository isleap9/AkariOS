using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Apps;
using AkariOS.Core.Presets;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>A row of the Apps step: its Tweak or Entry, on the PC or not, its grid and checkbox.</summary>
public sealed class AppRow(Tweak tweak, bool installed, Grid row, CheckBox box)
{
    public Tweak Tweak { get; } = tweak;

    /// <summary>An install's "Installed on this PC" mark (Show installed); a removal has none.</summary>
    public FrameworkElement? Mark { get; init; }

    /// <summary>A Caution install's mark (AppLists.InstallMark), in the Mark's column, hidden while that shows.</summary>
    public FrameworkElement? Caution { get; init; }
    public bool Installed { get; } = installed;
    public Grid Row { get; } = row;
    public CheckBox Box { get; } = box;
    public bool Removal => AppLists.IsRemoval(Tweak);
    internal bool Muted { get; set; }
}

/// <summary>
/// The Apps step (src/UI/Apps.ps1, after Win11Debloat's App Removal page): two tabs over one table look. Remove:
/// Store apps, Optional features, Windows features (read in the background once the tab shows) and legacy apps, with
/// Quick select (Guided only), Select recommended, AkariOS, Clear selection, Only installed. Install: a card per kind
/// of app, then the Store apps the debloat removed. Rows write into the Selection; nothing runs until Review &amp;
/// Apply. Guided shows both tabs; Downloads the Install tab alone, Remove apps the Remove tab alone.
/// </summary>
public sealed class AppsStep(AppServices s, IDictionary<string, Pending> sel, Action changed, Action<ContextMenu>? fillQuick)
{
    /// <summary>The Risk marks: Safe = recommended to remove, Caution = optional, Advanced = not recommended.</summary>
    public static IReadOnlyDictionary<Risk, (string Icon, string Brush, string Label)> Dots { get; } = new Dictionary<Risk, (string, string, string)>
    {
        [Risk.Safe] = ("circle-check", "Ok", "Recommended"),
        [Risk.Caution] = ("circle-minus", "Warn", "Optional"),
        [Risk.Advanced] = ("triangle-alert", "Bad", "Not recommended"),
    };

    private readonly Border _host = new();
    private readonly Dictionary<string, AppRow> _rows = [];
    private StackPanel? _view;
    private bool _reading;
    private string _query = "";
    private string _only = "";
    private bool _onlyInstalled = true;
    private Func<Tweak, bool>? _pick;
    private (Preset Preset, IReadOnlyList<string> Ids)? _pendingPick;
    private Ui? _p;

    // the view's parts the tabs, picks and feature read reach
    private sealed class Ui
    {
        public required StackPanel Tabs, RemoveBar, InstallBar, RemoveTables, InstallTables, Legend;
        public required Button RemoveTab, InstallTab, Uninstall, UpdateAll, ShowInstalled;
        public Button? Quick;
        public required Table Capabilities, Features;
        public required TextBlock Status;
    }

    private sealed record Table(StackPanel Rows, TextBlock Title, string Name);

    private sealed record ReadResult(IReadOnlyList<string> Installed, IReadOnlyList<string> Appx, IReadOnlyDictionary<string, string> Logos, IReadOnlyList<AppItem> Legacy);

    /// <summary>The rows by Tweak id, once built.</summary>
    public IReadOnlyDictionary<string, AppRow> Rows => _rows;

    /// <summary>The tab shown: Remove or Install.</summary>
    public string Tab { get; private set; } = "Remove";

    /// <summary>The feature lists were asked for (once, when the Remove tab first shows).</summary>
    public bool FeaturesRead { get; private set; }

    private IReadOnlyDictionary<string, string> _logos = new Dictionary<string, string>();

    /// <summary>"Only installed": rows of apps not on this PC are hidden.</summary>
    public bool OnlyInstalled
    {
        get => _onlyInstalled;
        set { _onlyInstalled = value; Filter(_query); }
    }

    /// <summary>The step: "Reading…" until the PC's apps are read, then the view (built once). only: "" = Guided
    /// (both tabs), "Install" (Downloads) or "Remove" (Remove apps): that tab alone, no tab buttons.</summary>
    public UIElement View(string query, string only)
    {
        _query = query;
        _only = only;
        Ensure();
        if (_view is not null) { ShowOnly(); Filter(query); }
        return _host;
    }

    /// <summary>Builds the view when it isn't (Quick select from another step needs the rows).</summary>
    public void Ensure()
    {
        if (_view is not null || _reading) return;
        _reading = true;
        _host.Child = Look.Parts.Text("Reading the apps on this PC…", 13, "Mu");
        s.Background(Read, r =>
        {
            _reading = false;
            Build(r as ReadResult ?? new ReadResult([], [], new Dictionary<string, string>(), []));
            _host.Child = _view;
            ShowOnly();
            Filter(_query);
            if (_pendingPick is { } p) { _pendingPick = null; QuickSelect(p.Preset, p.Ids); }
            // Downloads built anew after Show installed was asked for: its marks are read again
            if (_only == "Install" && s.Install is { ShowInstalled: true }) ReadInstalled();
        });
    }

    /// <summary>Show installed (after winutil's Get Installed): which installs are on this PC, read in the background
    /// with the page still usable (one "winget list", the other apps' Detects), then their rows marked. Remembered for
    /// the session, so a Downloads page built later shows its marks again. A hint only.</summary>
    public void ReadInstalled()
    {
        if (_view is null || _readingInstalled || s.Shell.Busy) return;
        if (s.Install is { } page) page.ShowInstalled = true;
        _readingInstalled = true;
        s.Shell.SetBusy(true, "Reading the installed apps", locked: false);
        var installs = s.Engine.Loaded.Tweaks.Where(t => t.Section == "Apps" && t.Category == "Install").ToList();
        s.Background(() =>
        {
            try { return AppKinds.InstalledApps(installs, s.Engine.Context); }
            catch (Exception e) { s.Log.Write($"Warning: the installed apps could not be read ({e.Message})"); return null; }
        }, r =>
        {
            _readingInstalled = false;
            s.Shell.SetBusy(false);
            if (r is not IReadOnlyList<string> ids) return;
            var have = ids.ToHashSet(StringComparer.Ordinal);
            foreach (var row in _rows.Values)
            {
                if (row.Mark is not { } mark) continue;
                var on = have.Contains(row.Tweak.Id);
                mark.Visibility = on ? Visibility.Visible : Visibility.Collapsed;
                // a Caution mark gives way to "Installed on this PC"
                if (row.Caution is { } c) c.Visibility = on ? Visibility.Collapsed : Visibility.Visible;
            }
        });
    }

    private bool _readingInstalled;

    /// <summary>The checked installs (Uninstall selected), in the page's order.</summary>
    public IReadOnlyList<Tweak> PickedInstalls() => _rows.Values.Where(r => !r.Removal && r.Box.IsChecked == true).Select(r => r.Tweak).ToList();

    // Get-AkariAppsView's reads, off the UI thread: one package read (the removable ones, every name for the restore
    // card, the installed apps' logos) and the legacy apps' Detects
    private ReadResult Read()
    {
        IReadOnlyList<string> installed = [], appx = [];
        IReadOnlyDictionary<string, string> logos = new Dictionary<string, string>();
        if (s.Engine.Services.Apps is { } apps)
        {
            try
            {
                var all = apps.All();
                installed = apps.Installed(all);
                appx = all.Select(p => p.Name).ToList();
                var have = installed.ToHashSet(StringComparer.OrdinalIgnoreCase);
                logos = AppPackages.Logos(all.Where(p => have.Contains(p.Name)));
            }
            catch (Exception e) { s.Log.Write($"Warning: the Store apps could not be read ({e.Message})"); }
        }
        var legacy = s.Engine.Loaded.Tweaks
            .Where(t => t.Section == "Apps" && t.Category == "Remove" && t.Group is null && (t.Requires.Count == 0 || Core.Machine.Requirements.Check(t, s.Engine.System) is null))
            .OrderBy(t => t.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(t => new AppItem(t, !Gone(t))).ToList();
        return new ReadResult(installed, appx, logos, legacy);
    }

    // Get-AkariLegacyRemoveList: installed = its Detect says not gone yet
    private bool Gone(Tweak t)
    {
        try { return t.Code is { } c && t.Blocks.Contains("Detect") && c.Detect(t, s.Engine.Context) == TweakState.Optimized; }
        catch (Exception) { return false; }
    }

    private void Build(ReadResult r)
    {
        _logos = r.Logos;
        _rows.Clear();
        var view = new StackPanel();
        var tabs = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 12) };
        var removeTab = Button("Remove", "Store apps, optional features, Windows features and legacy apps to remove", () => ShowTab("Remove"));
        var installTab = Button("Install", "Apps to install, from winget where possible", () => ShowTab("Install"));
        tabs.Children.Add(removeTab);
        tabs.Children.Add(installTab);
        view.Children.Add(tabs);

        // Remove toolbar: Quick select (a whole preset, Guided only), the quick picks, Only installed
        var removeBar = Bar();
        Button? quick = null;
        if (fillQuick is not null)
        {
            quick = Button("Quick select ▾", "Pick a preset: it replaces every pick, apps and Tweaks", null);
            quick.ContextMenu = new ContextMenu();
            quick.Click += (_, _) =>
            {
                fillQuick(quick.ContextMenu);
                quick.ContextMenu.PlacementTarget = quick;
                quick.ContextMenu.Placement = System.Windows.Controls.Primitives.PlacementMode.Bottom;
                quick.ContextMenu.IsOpen = true;
            };
            removeBar.Children.Add(quick);
        }
        removeBar.Children.Add(Button("Select recommended", "Win11Debloat's pick: what is on this PC and marked Recommended", () => Pick(AppLists.Recommended)));
        removeBar.Children.Add(Button("AkariOS", "The AkariOS debloat (FR33THY's): every Store app, optional feature, Windows feature and legacy app on this PC except its keep-list", () => Pick(AppLists.AkariOSPick)));
        removeBar.Children.Add(Button("Clear selection", "Uncheck everything to remove", () => Pick(_ => false)));
        var only = new CheckBox { Content = "Only installed", IsChecked = _onlyInstalled, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(8, 0, 0, 0) };
        only.SetResourceReference(FrameworkElement.StyleProperty, "Check");
        only.Click += (_, _) => OnlyInstalled = only.IsChecked == true;
        removeBar.Children.Add(only);
        view.Children.Add(removeBar);

        var installBar = Bar();
        installBar.Children.Add(Button("Clear selection", "Uncheck every app to install", ClearInstalls));
        // Downloads only (after Chris Titus Tech's winutil, MIT: Uninstall selected, Upgrade all, Get Installed): they
        // act right away, in the background (InstallPage)
        var uninstall = Button("Uninstall selected", "Uninstall the checked apps with winget, after asking", () => s.Install?.Uninstall());
        var updateAll = Button("Update all apps", "Update every app winget knows a newer version of", () => s.Install?.UpdateApps());
        var showInstalled = Button("Show installed", "Mark the apps of this list that are on this PC", ReadInstalled);
        foreach (var b in new[] { uninstall, updateAll, showInstalled }) installBar.Children.Add(b);
        view.Children.Add(installBar);

        // Remove: four sections; the two feature ones say "Reading…" until their background read is done
        var removeTables = new StackPanel();
        var store = NewTable("Store apps", "App ID", removeTables);
        AddRows(store, AppLists.Store(s.Engine.Loaded.Tweaks, s.Engine.Loaded.Groups, r.Installed));
        var caps = NewTable("Optional features", "Capability", removeTables);
        var feats = NewTable("Windows features", "Feature", removeTables);
        foreach (var t in new[] { caps, feats })
        {
            t.Rows.Children.Add(Cell("Reading what is on this PC...", 0, "Mu", 12));
            t.Title.Text = $"{t.Name} (reading...)";
        }
        AddRows(NewTable("Legacy apps", "Id", removeTables), r.Legacy);
        view.Children.Add(removeTables);

        // Install: a card per kind of app, then the Store apps the debloat removed
        var installTables = new StackPanel();
        foreach (var c in AppLists.InstallCards(s.Engine.Loaded.Tweaks, s.Engine.System, r.Appx))
        {
            var t = NewTable(c.Title, "Source", installTables);
            if (c.Items.Count == 0) t.Rows.Children.Add(Cell("Nothing to restore: every app in this list is on this PC.", 0, "Mu", 12));
            AddRows(t, c.Items);
        }
        view.Children.Add(installTables);

        // status and legend
        var foot = new DockPanel();
        var legend = new StackPanel { Orientation = Orientation.Horizontal };
        DockPanel.SetDock(legend, Dock.Right);
        foreach (var k in new[] { Risk.Safe, Risk.Caution, Risk.Advanced })
        {
            var m = RiskMark(k);
            m.Margin = new Thickness(16, 0, 6, 0);
            legend.Children.Add(m);
            legend.Children.Add(Cell(Dots[k].Label, 0, "Mu", 12));
        }
        foot.Children.Add(legend);
        var status = Cell("", 0, "Mu", 12);
        foot.Children.Add(status);
        view.Children.Add(foot);

        _p = new Ui
        {
            Tabs = tabs, RemoveBar = removeBar, InstallBar = installBar, RemoveTables = removeTables, InstallTables = installTables, Legend = legend,
            RemoveTab = removeTab, InstallTab = installTab, Uninstall = uninstall, UpdateAll = updateAll, ShowInstalled = showInstalled, Quick = quick, Capabilities = caps, Features = feats, Status = status,
        };
        _view = view;
        UpdateStatus();
    }

    // Set-AkariAppsOnly: an apps flow's tab alone, no tab buttons (Remove apps: no Quick select either)
    private void ShowOnly()
    {
        if (_p is null) return;
        _p.Tabs.Visibility = _only.Length > 0 ? Visibility.Collapsed : Visibility.Visible;
        if (_p.Quick is not null) _p.Quick.Visibility = _only.Length > 0 ? Visibility.Collapsed : Visibility.Visible;
        // Downloads' own buttons: not on Guided's Install tab, whose picks wait for Review & Apply
        _p.Uninstall.Visibility = _p.UpdateAll.Visibility = _p.ShowInstalled.Visibility = _only == "Install" ? Visibility.Visible : Visibility.Collapsed;
        ShowTab(_only.Length > 0 ? _only : Tab);
    }

    // Show-AkariAppsTab: one tab's toolbar and tables; the features are read the first time Remove shows
    private void ShowTab(string tab)
    {
        Tab = tab;
        if (_p is null) return;
        var remove = tab == "Remove";
        _p.RemoveBar.Visibility = _p.RemoveTables.Visibility = _p.Legend.Visibility = remove ? Visibility.Visible : Visibility.Collapsed;
        _p.InstallBar.Visibility = _p.InstallTables.Visibility = remove ? Visibility.Collapsed : Visibility.Visible;
        _p.RemoveTab.SetResourceReference(FrameworkElement.StyleProperty, remove ? "Accent" : "Btn");
        _p.InstallTab.SetResourceReference(FrameworkElement.StyleProperty, remove ? "Btn" : "Accent");
        if (remove && !FeaturesRead) ReadFeatures();
    }

    // Start-AkariFeatureRead / Complete-AkariFeatureRead
    private void ReadFeatures()
    {
        FeaturesRead = true;
        s.Background(() =>
        {
            if (s.Engine.Services.Apps is not { } apps) return null;
            try { return (apps.InstalledCapabilities(), apps.EnabledFeatures()); }
            catch (Exception e) { s.Log.Write($"Warning: the features could not be read ({e.Message})"); return null; }
        }, r =>
        {
            if (_p is null) return;
            var (caps, feats) = r is (IReadOnlyList<string> c, IReadOnlyList<string> f) ? (c, f) : ([], []);
            foreach (var (table, kind, names) in new[] { (_p.Capabilities, EntryKind.CapabilityRemove, caps), (_p.Features, EntryKind.FeatureDisable, feats) })
            {
                table.Rows.Children.Clear();
                if (r is null) table.Rows.Children.Add(Cell("Could not be read. Open the Apps step again to retry.", 0, "Bad", 12));
                var items = AppLists.Found(s.Engine.Loaded.Groups, kind, names);
                AddRows(table, items);
                // the last quick pick, applied to the rows that arrived after it
                if (_pick is { } pick) Pick(pick, items.Select(i => _rows[i.Tweak.Id]).ToList());
            }
            Filter(_query);
            UpdateStatus();
        });
    }

    // ---- rows

    private Table NewTable(string title, string last, Panel into)
    {
        var card = new Border();
        card.SetResourceReference(FrameworkElement.StyleProperty, "CategoryCard");
        card.Margin = new Thickness(0, 0, 0, 12);
        var sp = new StackPanel();
        var tt = Cell(title, 0, "Tx", 20);
        tt.FontWeight = FontWeights.SemiBold;
        tt.SetResourceReference(TextBlock.FontFamilyProperty, "FontDisplay");
        tt.Margin = new Thickness(0, 0, 0, 8);
        sp.Children.Add(tt);
        var head = Grid();
        head.Margin = new Thickness(0, 0, 0, 6);
        foreach (var (h, col) in new[] { ("Name", 3), ("Description", 4), (last, 5) })
        {
            var c = Cell(h, col, "Mu", 12);
            c.FontWeight = FontWeights.SemiBold;
            head.Children.Add(c);
        }
        sp.Children.Add(head);
        var rows = new StackPanel();
        sp.Children.Add(rows);
        card.Child = sp;
        into.Children.Add(card);
        return new Table(rows, tt, title);
    }

    // Add-AkariAppRows: the rows, and the count in the title
    private void AddRows(Table table, IEnumerable<AppItem> items)
    {
        foreach (var item in items)
        {
            var row = NewRow(item);
            _rows[item.Tweak.Id] = row;
            table.Rows.Children.Add(row.Row);
        }
        table.Title.Text = $"{table.Name} ({table.Rows.Children.OfType<Grid>().Count()})";
    }

    // the table's columns: checkbox | Risk mark | icon | name | description | App ID or source
    private static Grid Grid()
    {
        var g = new Grid();
        foreach (var w in new[] { 32, 22, 30, 240, 0, 260 })
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = w > 0 ? new GridLength(w) : new GridLength(1, GridUnitType.Star) });
        return g;
    }

    private static TextBlock Cell(string text, int col, string brush = "Tx", double size = 13)
    {
        var t = new TextBlock { Text = text, FontSize = size, TextTrimming = TextTrimming.CharacterEllipsis, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 12, 0) };
        t.SetResourceReference(TextBlock.ForegroundProperty, brush);
        System.Windows.Controls.Grid.SetColumn(t, col);
        return t;
    }

    /// <summary>New-AkariRiskMark: the Risk's 14 px Lucide icon in its colour, the label as tooltip.</summary>
    public static FrameworkElement RiskMark(Risk risk)
    {
        var d = Dots.TryGetValue(risk, out var x) ? x : Dots[Risk.Caution];
        var m = Icons.Make(d.Icon, 14, d.Brush);
        m.ToolTip = d.Label;
        m.HorizontalAlignment = HorizontalAlignment.Left;
        m.VerticalAlignment = VerticalAlignment.Center;
        return m;
    }

    // New-AkariAppRow: a removal has a Risk mark; an install its "Installed on this PC" mark and, when Caution, its InstallMark
    private AppRow NewRow(AppItem item)
    {
        var t = item.Tweak;
        var g = Grid();
        g.Margin = new Thickness(0, 3, 0, 3);
        g.Tag = t.Id;
        var box = new CheckBox { Tag = t.Id, VerticalAlignment = VerticalAlignment.Center };
        box.SetResourceReference(FrameworkElement.StyleProperty, "Check");
        g.Children.Add(box);
        FrameworkElement? mark = null, caution = null;
        if (AppLists.IsRemoval(t))
        {
            var dot = RiskMark(t.Risk);
            System.Windows.Controls.Grid.SetColumn(dot, 1);
            g.Children.Add(dot);
        }
        else
        {
            // an install: the "on this PC" mark, shown by Show installed
            mark = Icons.Make("circle-check", 14, "Ok");
            mark.ToolTip = "Installed on this PC";
            mark.HorizontalAlignment = HorizontalAlignment.Left;
            mark.VerticalAlignment = VerticalAlignment.Center;
            mark.Visibility = Visibility.Collapsed;
            System.Windows.Controls.Grid.SetColumn(mark, 1);
            g.Children.Add(mark);
            // a Caution install: its mark in the same column, hidden while the app shows as installed
            if (AppLists.InstallMark(t) is { } m)
            {
                caution = Icons.Make(m.Icon, 14, m.Brush);
                caution.ToolTip = m.Tip;
                caution.HorizontalAlignment = HorizontalAlignment.Left;
                caution.VerticalAlignment = VerticalAlignment.Center;
                System.Windows.Controls.Grid.SetColumn(caution, 1);
                g.Children.Add(caution);
            }
        }
        var icon = AppIcons.Make(t, _logos);
        System.Windows.Controls.Grid.SetColumn(icon, 2);
        var name = Cell(t.Name, 3);
        if (t.Keep) name.ToolTip = "Kept by the AkariOS pick (FR33THY's keep-list)";
        if (!item.Installed) name.Opacity = icon.Opacity = 0.6;
        g.Children.Add(icon);
        g.Children.Add(name);
        var desc = Cell(string.IsNullOrEmpty(t.Description) ? "Not in Akari's list: found on this PC" : t.Description, 4, "Mu");
        desc.ToolTip = desc.Text;
        g.Children.Add(desc);
        var src = AppLists.Source(t);
        var pkg = Cell(src, 5, "Ter", 12);
        pkg.ToolTip = item.Installed ? src : $"{src} (not on this PC)";
        g.Children.Add(pkg);
        var row = new AppRow(t, item.Installed, g, box) { Mark = mark, Caution = caution };
        box.Click += (_, _) => Step(row);
        return row;
    }

    // Step-AkariAppCheck: checked = Remove or Install (an Advanced item asks first), unchecked = no change
    private void Step(AppRow r)
    {
        if (r.Muted) return;
        var next = r.Box.IsChecked == true ? Selection.Optimized : Selection.None;
        if (Selection.ConfirmText(r.Tweak, next, null) is { } q && s.Dialogs?.Confirm(q, "Continue") != true) { Set(r, false); UpdateStatus(); return; }
        Selection.SetPending(sel, r.Tweak, TweakState.Unknown, next, null, null);
        UpdateStatus();
    }

    // Set-AkariAppChecked
    private void Set(AppRow r, bool on)
    {
        r.Muted = true;
        try { r.Box.IsChecked = on; } finally { r.Muted = false; }
        Selection.SetPending(sel, r.Tweak, TweakState.Unknown, on ? Selection.Optimized : Selection.None, null, null);
    }

    // Select-AkariApps: the removals on this PC the pick says yes to are checked, every other one unchecked (no
    // confirmation: Review lists them all). Remembered, so the features read later get it too.
    private void Pick(Func<Tweak, bool> pick) { _pick = pick; Pick(pick, _rows.Values.Where(r => r.Removal).ToList()); UpdateStatus(); }

    private void Pick(Func<Tweak, bool> pick, IReadOnlyList<AppRow> rows)
    {
        foreach (var r in rows) Set(r, r.Installed && pick(r.Tweak));
    }

    private void ClearInstalls()
    {
        foreach (var r in _rows.Values.Where(r => !r.Removal)) Set(r, false);
        UpdateStatus();
    }

    /// <summary>Set-AkariQuickSelect's apps: every row unchecked, then a preset's removals (its "&lt;group&gt;/*" Groups
    /// but their Keep Entries, and the ids it resolved to) and installs checked; waits for the view.</summary>
    public void QuickSelect(Preset preset, IReadOnlyList<string> resolvedIds)
    {
        Ensure();
        if (_view is null) { _pendingPick = (preset, resolvedIds); return; }
        foreach (var r in _rows.Values) Set(r, false);
        var pick = AppLists.PresetPick(preset.Entries.Select(e => e.Id), resolvedIds);
        _pick = pick;
        Pick(pick, _rows.Values.Where(r => r.Removal).ToList());
        var ids = resolvedIds.ToHashSet(StringComparer.Ordinal);
        foreach (var r in _rows.Values.Where(r => !r.Removal && ids.Contains(r.Tweak.Id))) Set(r, true);
        UpdateStatus();
    }

    /// <summary>The picks to remove and to install.</summary>
    public (int Remove, int Install) Counts()
    {
        var on = _rows.Values.Where(r => r.Box.IsChecked == true).ToList();
        var rm = on.Count(r => r.Removal);
        return (rm, on.Count - rm);
    }

    private void UpdateStatus()
    {
        if (_p is not null)
        {
            var (rm, inst) = Counts();
            _p.Status.Text = $"{rm} to remove, {inst} to install";
            _p.Uninstall.IsEnabled = inst > 0;
        }
        changed();
    }

    /// <summary>Set-AkariAppsFilter: the header search and Only installed hide the rows that don't match.</summary>
    public void Filter(string q)
    {
        _query = q;
        foreach (var r in _rows.Values)
        {
            var t = r.Tweak;
            var hit = q.Length == 0 || Core.Data.PsSemantics.Like($"{t.Name} {t.Description} {AppLists.Source(t)}", $"*{q}*");
            if (_onlyInstalled && !r.Installed) hit = false;
            r.Row.Visibility = hit ? Visibility.Visible : Visibility.Collapsed;
        }
    }

    private static StackPanel Bar() => new() { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 12) };

    private static Button Button(string text, string tip, Action? click)
    {
        var b = Look.Parts.Button(text, click: click);
        b.ToolTip = tip;
        b.Margin = new Thickness(0, 0, 8, 0);
        return b;
    }
}
