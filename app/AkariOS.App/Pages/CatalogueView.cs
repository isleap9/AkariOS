using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>
/// One setting card (New-AkariCatalogueCard): name, the id in mono with its badges, the description, the State line,
/// restart / Safe Mode marks, and its control: a switch for a Toggle (empty for Custom / Unknown), a dropdown for a
/// Choice, a button for an Action. Made once per Tweak and kept.
/// </summary>
public sealed class CatalogueCard
{
    public required Tweak Tweak { get; init; }
    public required Border Card { get; init; }
    public required Control Control { get; init; }
    public required TextBlock StateLine { get; init; }
    public TweakState State { get; set; } = TweakState.Unknown;
    public object? Current { get; set; }
    public CatalogueBusy Busy { get; set; }
    public string Error { get; set; } = "";

    /// <summary>Why the native app can't change it yet (its control is off), or null.</summary>
    public string? NotNative { get; init; }

    // the control is being set from the State: no change comes of it
    internal bool Muted;

    /// <summary>The State line and the control after a change of State, Busy or Error (Set-AkariCatalogueCard).</summary>
    public void Update(bool safePending = false)
    {
        if (Error.Length > 0)
        {
            StateLine.Text = $"Failed: {Error}";
            StateLine.SetResourceReference(TextBlock.ForegroundProperty, "Bad");
        }
        else
        {
            StateLine.Text = Catalogue.StateText(Tweak, State, Busy, safePending);
            StateLine.SetResourceReference(TextBlock.ForegroundProperty, safePending ? "Warn" : "Ter");
        }
        StateLine.Visibility = StateLine.Text.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        Control.IsEnabled = Busy == CatalogueBusy.None && NotNative is null;
        Muted = true;
        try
        {
            switch (Control)
            {
                case ToggleButton sw:
                    sw.IsChecked = State switch { TweakState.Optimized => true, TweakState.Default => false, _ => null };
                    break;
                case ComboBox box:
                    var item = Current is null ? null : box.Items.OfType<ComboBoxItem>().FirstOrDefault(i => RegistryEngine.Matches(Current, i.Tag));
                    if (item is null) box.SelectedIndex = -1; else box.SelectedItem = item;
                    break;
            }
        }
        finally { Muted = false; }
    }
}

/// <summary>
/// Optimize › Advanced, the Catalogue's page (src/UI/CataloguePage.ps1): a Category page or the search results, its
/// cards (kept per Tweak), a Refresh button, the States read in the background one by one. A change made on a card
/// goes to <see cref="Change"/>.
/// </summary>
public sealed class CatalogueView(AppServices s)
{
    private readonly Dictionary<string, CatalogueCard> _cards = [];
    private IReadOnlyList<Tweak>? _tweaks;
    private Panel? _shown;
    private string _shownKey = "";
    private string _movedKey = "";

    /// <summary>The Tweaks it lists (this PC's).</summary>
    public IReadOnlyList<Tweak> Tweaks => _tweaks ??= Catalogue.Tweaks(s.Engine.Loaded.Tweaks, s.Engine.System);

    /// <summary>A card's control was used: the Tweak, Apply or Revert, a Choice value other than Recommended.</summary>
    public Action<Tweak, TweakMode, object?>? Change { get; set; }

    /// <summary>A card, made the first time.</summary>
    public CatalogueCard Card(Tweak t) => _cards.TryGetValue(t.Id, out var c) ? c : _cards[t.Id] = NewCard(t);

    /// <summary>Show-AkariCataloguePage: a page (key) or, with a query, the search's results across the Catalogue.
    /// The Services and Scheduled tasks pages keep their Tweaks while the search waits for their lists (N6).</summary>
    public UIElement Build(string page, string query)
    {
        var lists = Catalogue.Lists.ContainsKey(page);
        if (lists) query = "";
        var list = Catalogue.List(Tweaks, page, query);
        // the cards are kept: take them off the page shown before
        _shown?.Children.Clear();
        var panel = new StackPanel();
        _shown = panel;

        var bar = new DockPanel { Margin = new Thickness(0, 0, 0, 12) };
        var refresh = Parts.Button("Refresh", click: () => ReadStates(Catalogue.List(Tweaks, page, query)));
        refresh.Margin = new Thickness(0);
        refresh.ToolTip = "Read the current state of these tweaks again";
        DockPanel.SetDock(refresh, Dock.Right);
        bar.Children.Add(refresh);
        var count = Parts.Text($"{list.Count} tweak{(list.Count == 1 ? "" : "s")}", 13, "Mu");
        count.VerticalAlignment = VerticalAlignment.Center;
        bar.Children.Add(count);
        panel.Children.Add(bar);

        var last = "";
        foreach (var t in list)
        {
            // search results: a heading per Section › Category
            var key = Catalogue.Key(t.Section, t.Category);
            if (query.Length > 0 && key != last)
            {
                last = key;
                var h = Parts.Title($"{Catalogue.HeaderOf(t.Section)} › {t.Category}", 14);
                h.Margin = new Thickness(2, 12, 0, 6);
                panel.Children.Add(h);
            }
            var c = Card(t);
            panel.Children.Add(c.Card);
            c.Update();
        }
        if (list.Count == 0) panel.Children.Add(Parts.Text(query.Length > 0 ? "No tweak matches." : "Nothing here yet.", 13, "Mu"));
        if (lists)
        {
            var note = Parts.Text($"The list of {(page.EndsWith("Services", StringComparison.Ordinal) ? "services" : "scheduled tasks")} on this PC comes with N6 (docs/plans/2026-10-31-native-app.md). The PowerShell app has it today.", 13, "Mu");
            note.Margin = new Thickness(2, 12, 0, 0);
            panel.Children.Add(note);
        }

        // the same page and search again (Show-Page's rebuild) reads nothing; another page, or the search starting or
        // ending, staggers its cards in
        var shown = $"{page}|{query}";
        var moved = $"{page}|{query.Length > 0}";
        if (shown != _shownKey) ReadStates(list);
        if (moved != _movedKey) Motion.Stagger(panel.Children.OfType<UIElement>());
        (_shownKey, _movedKey) = (shown, moved);
        return panel;
    }

    /// <summary>Start-AkariCatalogueStates: the Toggles' and Choices' States, read off the UI thread one after another
    /// (a card says "Reading…" until its own arrives); cards busy with a change are left alone.</summary>
    public void ReadStates(IEnumerable<Tweak> tweaks)
    {
        var queue = new Queue<CatalogueCard>();
        foreach (var t in tweaks.Where(t => t.Kind != TweakKind.Action))
        {
            var c = Card(t);
            if (c.Busy != CatalogueBusy.None) continue;
            c.Busy = CatalogueBusy.Reading;
            c.Error = "";
            c.Update();
            queue.Enqueue(c);
        }
        ReadNext(queue);
    }

    private void ReadNext(Queue<CatalogueCard> queue)
    {
        if (!queue.TryDequeue(out var c)) return;
        s.Background(() => Read(c.Tweak), r =>
        {
            var read = r as StateRead ?? new StateRead(TweakState.Unknown, null);
            if (c.Busy == CatalogueBusy.Reading)
            {
                (c.State, c.Current, c.Busy) = (read.State, read.Current, CatalogueBusy.None);
                c.Update();
            }
            ReadNext(queue);
        });
    }

    private sealed record StateRead(TweakState State, object? Current);

    // a State that can't be read is Unknown
    private StateRead Read(Tweak t)
    {
        var state = TweakState.Unknown;
        try { state = s.Engine.States.Of(t); } catch (Exception) { }
        object? current = null;
        if (t.Kind == TweakKind.Choice) try { current = s.Engine.States.ChoiceValue(t); } catch (Exception) { }
        return new StateRead(state, current);
    }

    private CatalogueCard NewCard(Tweak t)
    {
        var card = new Border { Tag = t.Id, Margin = new Thickness(0, 0, 0, 8) };
        card.SetResourceReference(FrameworkElement.StyleProperty, "SettingCard");
        var dp = new DockPanel();
        var notNative = Runner.NotNative(t);
        CatalogueCard? entry = null;
        Control ctl;
        switch (t.Kind)
        {
            case TweakKind.Toggle:
                var sw = new ToggleButton();
                sw.SetResourceReference(FrameworkElement.StyleProperty, "CatSwitch");
                sw.Click += (_, _) => Changed(entry!, sw.IsChecked == true ? TweakMode.Apply : TweakMode.Revert, null);
                ctl = sw;
                break;
            case TweakKind.Choice:
                var box = new ComboBox { Width = 220 };
                box.SetResourceReference(FrameworkElement.StyleProperty, "Combo");
                var def = s.Engine.States.DefaultFor(t);
                foreach (var c in t.Choices)
                {
                    var label = c.Label.Length > 0 ? c.Label : $"{c.Value}";
                    if (RegistryEngine.Matches(c.Value, t.Recommended)) label += " (Recommended)";
                    else if (RegistryEngine.Matches(c.Value, def)) label += " (Windows default)";
                    box.Items.Add(new ComboBoxItem { Content = label, Tag = c.Value });
                }
                box.SelectionChanged += (_, _) =>
                {
                    if (entry!.Muted || box.SelectedItem is not ComboBoxItem { Tag: var v }) return;
                    if (RegistryEngine.Matches(v, s.Engine.States.DefaultFor(t))) Changed(entry, TweakMode.Revert, null);
                    else if (RegistryEngine.Matches(v, t.Recommended)) Changed(entry, TweakMode.Apply, null);
                    else Changed(entry, TweakMode.Apply, v);
                };
                ctl = box;
                break;
            default:
                var btn = new Button { Content = t.Button, MinWidth = 96 };
                btn.SetResourceReference(FrameworkElement.StyleProperty, "Btn");
                btn.Click += (_, _) => Changed(entry!, TweakMode.Apply, null);
                ctl = btn;
                break;
        }
        ctl.Tag = t.Id;
        ctl.VerticalAlignment = VerticalAlignment.Center;
        ctl.Margin = new Thickness(16, 0, 0, 0);
        if (notNative is not null) ctl.ToolTip = $"Not in the native app yet: {notNative}";
        DockPanel.SetDock(ctl, Dock.Right);
        dp.Children.Add(ctl);

        var marks = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(marks, Dock.Right);
        if (t.Reboot) marks.Children.Add(Parts.Glyph("rotate-ccw", "Mu", "Restart required"));
        if (t.SafeMode) marks.Children.Add(Parts.Glyph("shield", "Mu", "Runs in Safe Mode: Akari restarts into it and back"));
        dp.Children.Add(marks);

        var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        var name = Parts.Text(t.Name, 14);
        name.FontWeight = FontWeights.SemiBold;
        text.Children.Add(name);
        var meta = new WrapPanel { Margin = new Thickness(0, 4, 0, 0) };
        var id = Parts.Text(t.Id, 12, "Ter");
        id.SetResourceReference(TextBlock.FontFamilyProperty, "FontMono");
        id.Margin = new Thickness(0, 0, 10, 0);
        id.VerticalAlignment = VerticalAlignment.Center;
        meta.Children.Add(id);
        if (t.AkariOS) meta.Children.Add(Parts.Badge("AkariOS"));
        if (t.Risk is Risk.Caution or Risk.Advanced) meta.Children.Add(Parts.Badge(t.Risk.ToString()));
        text.Children.Add(meta);
        if (!string.IsNullOrEmpty(t.Description))
        {
            var d = Parts.Text(t.Description, 13, "Mu");
            d.Margin = new Thickness(0, 6, 0, 0);
            text.Children.Add(d);
        }
        var line = Parts.Text("", 12, "Ter");
        line.Margin = new Thickness(0, 4, 0, 0);
        text.Children.Add(line);
        if (notNative is not null)
        {
            var nn = Parts.Text("Not in the native app yet: the PowerShell app can change it today.", 12, "Ter");
            nn.Margin = new Thickness(0, 4, 0, 0);
            text.Children.Add(nn);
        }
        dp.Children.Add(text);
        card.Child = dp;
        entry = new CatalogueCard { Tweak = t, Card = card, Control = ctl, StateLine = line, NotNative = notNative };
        return entry;
    }

    // the control shows what was there until the change runs (batch c: the queue)
    private void Changed(CatalogueCard c, TweakMode mode, object? value)
    {
        Change?.Invoke(c.Tweak, mode, value);
        c.Update();
    }
}
