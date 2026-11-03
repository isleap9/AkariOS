using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Shapes;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Data;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>
/// The Guided Tweaks step (Get-AkariTweaksView, src/UI/Steps.ps1), after Win11Debloat's System Tweaks: a toolbar
/// (Quick select, Clear selection, Show current state), then per Section a heading and a masonry grid of Category
/// cards with a row per Tweak. Every State is read once, in the background, before the view is built. The rows write
/// into the Selection; nothing changes on the PC here.
/// </summary>
public sealed class TweaksStep(AppServices s, IDictionary<string, Pending> sel, Action changed)
{
    private sealed record Card(Border Border, StackPanel Panel, int Size, string Section);
    private sealed record SectionView(string Section, TextBlock Heading, Grid Grid);
    private sealed record StateRead(TweakState State, object? Current);

    private readonly Border _host = new();
    private readonly Dictionary<string, TweakRow> _rows = [];
    private readonly List<Card> _cards = [];
    private readonly List<SectionView> _sections = [];
    private StackPanel? _view;
    private bool _reading;
    private int _cols;
    private string _query = "";
    private Preset? _pending;

    /// <summary>"Show current state": rows start on the State read from this PC (Win11Debloat's "Show currently
    /// applied tweaks").</summary>
    public bool UseState { get; private set; } = true;

    /// <summary>The rows by Tweak id, once built.</summary>
    public IReadOnlyDictionary<string, TweakRow> Rows => _rows;

    /// <summary>The step: "Reading…" until every State is read, then the view (built once).</summary>
    public UIElement View(string query)
    {
        _query = query;
        if (_view is null && !_reading) Read();
        if (_view is not null) Filter(query);
        return _host;
    }

    /// <summary>Builds the view now when it isn't (Quick select from another step needs the rows).</summary>
    public void Ensure() { if (_view is null && !_reading) Read(); }

    private void Read()
    {
        _reading = true;
        _host.Child = Parts.Text("Reading the current state of each tweak…", 13, "Mu");
        var groups = Selection.StepGroups(s.Engine.Loaded.Tweaks, s.Engine.System);
        var tweaks = groups.SelectMany(g => g.Categories).SelectMany(c => c.Ids).Select(id => s.Engine.Loaded.Find(id)!).ToList();
        s.Background(() => tweaks.ToDictionary(t => t.Id, Read), r =>
        {
            _reading = false;
            Build(groups, r as Dictionary<string, StateRead> ?? []);
            _host.Child = _view;
            Filter(_query);
            if (_pending is { } p) { _pending = null; QuickSelect(p); }
        });
    }

    private StateRead Read(Tweak t)
    {
        var state = TweakState.Unknown;
        try { state = s.Engine.States.Of(t); } catch (Exception) { }
        object? current = null;
        if (t.Kind == TweakKind.Choice) try { current = s.Engine.States.ChoiceValue(t); } catch (Exception) { }
        return new StateRead(state, current);
    }

    private void Build(IReadOnlyList<StepSection> groups, Dictionary<string, StateRead> states)
    {
        var view = new StackPanel();
        view.Children.Add(Toolbar());
        foreach (var g in groups)
        {
            var heading = Parts.Title(g.Header, 20);
            heading.Margin = new Thickness(2, _sections.Count == 0 ? 0 : 12, 0, 10);
            var grid = new Grid();
            view.Children.Add(heading);
            view.Children.Add(grid);
            _sections.Add(new SectionView(g.Section, heading, grid));
            foreach (var c in g.Categories)
            {
                var (card, panel, count) = CategoryCard(c.Name);
                var size = 0;
                foreach (var id in c.Ids)
                {
                    var t = s.Engine.Loaded.Find(id)!;
                    var st = states.GetValueOrDefault(id) ?? new StateRead(TweakState.Unknown, null);
                    var row = TweakRow.Make(t, st.State, st.Current, s.Engine.States.DefaultFor(t));
                    Hook(row);
                    _rows[id] = row;
                    // a dashed rule between rows (it hides with its row)
                    if (panel.Children.Count > 1) panel.Children.Add(Rule(row.Row));
                    panel.Children.Add(row.Row);
                    size += t.Kind == TweakKind.Choice ? 2 : 1;
                }
                count.Text = $"{c.Ids.Count}";
                _cards.Add(new Card(card, panel, size, g.Section));
            }
        }
        _view = view;
        _cols = 0;
        SetColumns(3);
        // three columns from 900 px, two below (Win11Debloat folds its third column the same way)
        view.SizeChanged += (_, e) => SetColumns(e.NewSize.Width >= 900 ? 3 : 2);
        Reset();
    }

    // ---- rows

    private void Hook(TweakRow row)
    {
        switch (row.Control)
        {
            case CheckBox box:
                box.Click += (_, _) => Check(row);
                break;
            case Selector pick:
                pick.SelectionChanged += (_, _) =>
                {
                    if (pick.SelectedItem is ContentControl it) Pick(row, pick.SelectedIndex == 0 ? Selection.None : it.Tag!);
                };
                if (pick is ComboBox { IsEditable: true } combo)
                    combo.LostKeyboardFocus += (_, _) =>
                    {
                        if (combo.IsKeyboardFocusWithin) return;
                        if (row.PickedValue() is { } v) Pick(row, v); else row.SetControl(row.Shown);
                    };
                break;
        }
    }

    // Step-AkariCheck: checked = Apply (asked first when needed), unchecked = Revert or no change
    private void Check(TweakRow row)
    {
        if (row.Muted) return;
        var t = row.Tweak;
        var next = Selection.CheckTarget(((CheckBox)row.Control).IsChecked == true, row.Initial);
        if (Selection.ConfirmText(t, next, row.WindowsDefault) is { } q && s.Dialogs?.Confirm(q, "Continue") != true)
        {
            row.SetControl(((CheckBox)row.Control).IsChecked == true ? Selection.None : Selection.Optimized);
            return;
        }
        Selection.SetPending(sel, t, row.State, next, null, row.WindowsDefault);
        changed();
    }

    // Set-AkariChoiceTarget: a Choice row picked a value (None = No change)
    private void Pick(TweakRow row, object value)
    {
        if (row.Muted) return;
        var none = value as string == Selection.None;
        var same = none ? row.Shown as string == Selection.None : row.Shown as string != Selection.None && RegistryEngine.Matches(value, row.Shown);
        if (same) return;
        if (!none && Selection.ConfirmText(row.Tweak, value, row.WindowsDefault) is { } q && s.Dialogs?.Confirm(q, "Continue") != true)
        {
            row.SetControl(row.Shown);
            return;
        }
        row.Shown = value;
        Selection.SetPending(sel, row.Tweak, row.State, value, row.Current, row.WindowsDefault);
        changed();
    }

    /// <summary>Reset-AkariTweakRows: every row back where it starts (per "Show current state"), its change out of
    /// the Selection, and the changes a preset brought for Tweaks with no row here.</summary>
    public void Reset()
    {
        foreach (var row in _rows.Values)
        {
            row.Initial = row.Shown = Selection.RowStart(row.Tweak, row.State, row.Current, UseState);
            row.SetControl(row.Initial);
            sel.Remove(row.Tweak.Id);
        }
        foreach (var id in sel.Where(p => p.Value.Hidden).Select(p => p.Key).ToList()) sel.Remove(id);
        changed();
    }

    // ---- Quick select (a preset replaces the whole Selection)

    /// <summary>Set-AkariQuickSelect: every row back where it starts, then the preset's changes picked. A Toggle or
    /// Choice with no row here (Guided = $false) is selected all the same, marked Hidden; apps wait for N5.</summary>
    public void QuickSelect(Preset preset)
    {
        Ensure();
        // the States are still being read: picked once the view is built
        if (_view is null) { _pending = preset; return; }
        var plan = PresetStore.Resolve(preset, s.Engine.Loaded.Tweaks);
        Reset();
        sel.Clear();
        var missing = 0;
        foreach (var i in plan.Items)
        {
            var t = s.Engine.Find(i.Id);
            if (t is null) { missing++; continue; }
            var def = s.Engine.States.DefaultFor(t);
            // a Choice's Revert is its Default value (null when Windows has none: Revert all the same)
            object? target = i.Mode == TweakMode.Revert ? (t.Kind == TweakKind.Choice ? def : Selection.Default)
                : t.Kind == TweakKind.Choice ? i.Value ?? t.Recommended : Selection.Optimized;
            if (_rows.TryGetValue(i.Id, out var row))
            {
                row.SetControl(target is null || target as string == Selection.Default ? Selection.None : target);
                if (t.Kind == TweakKind.Choice) row.Shown = target ?? Selection.None;
                Selection.SetPending(sel, t, row.State, target, row.Current, def);
            }
            else if (PresetStore.ExportTweaks([t], s.Engine.System).Count > 0) Hidden(t, target, def);
            else missing++;
        }
        changed();
        var unknown = missing + plan.Unknown.Count;
        s.Log.Write($"Quick select: {preset.Name}, {sel.Count} changes{(unknown > 0 ? $" ({unknown} not on this PC or not shown here)" : "")}");
    }

    // Set-AkariHiddenPending: its State read now, the change marked Hidden
    private void Hidden(Tweak t, object? target, object? def)
    {
        var r = Read(t);
        Selection.SetPending(sel, t, r.State, target, r.Current, def);
        if (sel.TryGetValue(t.Id, out var p)) sel[t.Id] = p with { Hidden = true };
    }

    /// <summary>The presets Quick select lists: built-in, Last used, the user's.</summary>
    public IReadOnlyList<Preset> Presets()
    {
        var all = s.Engine.Presets.All();
        return [.. all.Where(p => p.Builtin), .. s.Engine.Presets.LastUsed() is { } last ? [last] : Array.Empty<Preset>(), .. all.Where(p => !p.Builtin)];
    }

    /// <summary>Save-AkariQuickSelect: the Selection as a user preset, named by the user.</summary>
    public void SavePreset()
    {
        if (sel.Count == 0) { s.Dialogs?.Message("Pick some changes first, then save them as a preset."); return; }
        if (s.Dialogs?.ReadText("A name for this preset:", "Save", "Save as preset") is not { Length: > 0 } name) return;
        var path = s.Engine.Presets.Save(name, Selection.PlanItems(sel.Values), "Saved from Install AkariOS");
        s.Log.Write($"Preset saved: {path}");
    }

    private StackPanel Toolbar()
    {
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 16) };
        var quick = Parts.Button("Quick select ▾");
        quick.Margin = new Thickness(0);
        quick.ToolTip = "Pick a preset: it replaces every pick on this step";
        quick.ContextMenu = new ContextMenu();
        quick.Click += (_, _) => { FillQuickMenu(quick.ContextMenu); quick.ContextMenu.PlacementTarget = quick; quick.ContextMenu.Placement = PlacementMode.Bottom; quick.ContextMenu.IsOpen = true; };
        var clear = Parts.Button("Clear selection", click: Reset);
        clear.ToolTip = "Undo every pick on this page";
        clear.Margin = new Thickness(8, 0, 16, 0);
        var show = new CheckBox { Content = "Show current state", IsChecked = UseState, VerticalAlignment = VerticalAlignment.Center,
            ToolTip = "Check the Tweaks already applied on this PC. Unchecking one of them reverts it." };
        show.SetResourceReference(FrameworkElement.StyleProperty, "Check");
        show.Click += (_, _) => { UseState = show.IsChecked == true; Reset(); };
        bar.Children.Add(quick);
        bar.Children.Add(clear);
        bar.Children.Add(show);
        return bar;
    }

    /// <summary>The Quick select menu, built each time it opens (a preset saved just now is listed).</summary>
    public void FillQuickMenu(ContextMenu menu)
    {
        menu.Items.Clear();
        foreach (var p in Presets())
        {
            var it = new MenuItem { Header = p.Builtin && p.Name == "AkariOS" ? "AkariOS (recommended)" : p.Name, ToolTip = p.Description, Tag = p };
            it.Click += (_, _) => QuickSelect(p);
            menu.Items.Add(it);
        }
        menu.Items.Add(new Separator());
        var save = new MenuItem { Header = "Save current as preset…" };
        save.Click += (_, _) => SavePreset();
        menu.Items.Add(save);
    }

    // ---- layout and filter

    // Set-AkariTweaksColumns: each Section's cards in that many columns (masonry), again when the width crosses 900
    private void SetColumns(int cols)
    {
        if (cols == _cols) return;
        _cols = cols;
        foreach (var sec in _sections)
        {
            var cards = _cards.Where(c => c.Section == sec.Section).ToList();
            foreach (var p in sec.Grid.Children.OfType<Panel>()) p.Children.Clear();
            sec.Grid.Children.Clear();
            sec.Grid.ColumnDefinitions.Clear();
            var panels = new List<StackPanel>();
            for (var i = 0; i < cols; i++)
            {
                sec.Grid.ColumnDefinitions.Add(new ColumnDefinition());
                var p = new StackPanel { Margin = new Thickness(i > 0 ? 6 : 0, 0, i < cols - 1 ? 6 : 0, 0) };
                Grid.SetColumn(p, i);
                sec.Grid.Children.Add(p);
                panels.Add(p);
            }
            var at = Selection.Masonry(cards.Select(c => c.Size).ToList(), cols);
            for (var i = 0; i < cards.Count; i++) panels[at[i]].Children.Add(cards[i].Border);
        }
    }

    /// <summary>The header search on this step (Set-AkariTweaksFilter): rows that don't match hide, then cards left
    /// empty, then Sections left empty.</summary>
    public void Filter(string q)
    {
        foreach (var row in _rows.Values)
            row.Row.Visibility = q.Length == 0 || PsSemantics.Like($"{row.Tweak.Name} {row.Tweak.Description}", $"*{q}*") ? Visibility.Visible : Visibility.Collapsed;
        foreach (var c in _cards)
            // the card's head is the first child: only its rows count
            c.Border.Visibility = c.Panel.Children.OfType<DockPanel>().Skip(1).Any(r => r.Visibility == Visibility.Visible) ? Visibility.Visible : Visibility.Collapsed;
        foreach (var sec in _sections)
            sec.Heading.Visibility = _cards.Any(c => c.Section == sec.Section && c.Border.Visibility == Visibility.Visible) ? Visibility.Visible : Visibility.Collapsed;
    }

    // New-AkariCategoryCard: the icon blob, the title, the count pill; rows go into the panel
    private static (Border Card, StackPanel Panel, TextBlock Count) CategoryCard(string title)
    {
        var card = new Border { Margin = new Thickness(0, 0, 0, 12), Tag = title };
        card.SetResourceReference(FrameworkElement.StyleProperty, "CategoryCard");
        var panel = new StackPanel();
        var head = new DockPanel { Margin = new Thickness(0, 0, 0, 10) };
        var count = Parts.Text("", 12, "Mu");
        count.SetResourceReference(TextBlock.FontFamilyProperty, "FontMono");
        var pill = new Border { CornerRadius = new CornerRadius(10), Padding = new Thickness(8, 1, 8, 2), BorderThickness = new Thickness(1), VerticalAlignment = VerticalAlignment.Center, Child = count };
        pill.SetResourceReference(Border.BackgroundProperty, "Ctl");
        pill.SetResourceReference(Border.BorderBrushProperty, "CtlBd");
        DockPanel.SetDock(pill, Dock.Right);
        var ic = Parts.Blob(Icons.Category(title), 36);
        ic.Margin = new Thickness(0, 0, 12, 0);
        DockPanel.SetDock(ic, Dock.Left);
        var tt = Parts.Title(title, 20);
        tt.VerticalAlignment = VerticalAlignment.Center;
        tt.TextTrimming = TextTrimming.CharacterEllipsis;
        tt.TextWrapping = TextWrapping.NoWrap;
        head.Children.Add(pill);
        head.Children.Add(ic);
        head.Children.Add(tt);
        panel.Children.Add(head);
        card.Child = panel;
        return (card, panel, count);
    }

    // New-AkariRule: the dashed rule between two rows, shown only while the row under it is
    private static Line Rule(UIElement row)
    {
        var l = new Line { X1 = 0, X2 = 1, Stretch = Stretch.Fill, Height = 1, StrokeThickness = 1, StrokeDashArray = [4, 3], Margin = new Thickness(0, 2, 0, 2) };
        l.SetResourceReference(Shape.StrokeProperty, "Bd");
        l.SetBinding(UIElement.VisibilityProperty, new Binding("Visibility") { Source = row });
        return l;
    }
}
