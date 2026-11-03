using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>
/// One setting card (New-AkariCatalogueCard): name, the id in mono with its badges, the description, the State line,
/// restart / Safe Mode marks, and its control: a switch for a Toggle (empty for Custom / Unknown), a dropdown for a
/// Choice, a button for an Action. Made once per Tweak and kept by <see cref="CatalogueView"/>.
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

    /// <summary>A Choice's Windows default on this PC.</summary>
    public object? WindowsDefault { get; init; }

    /// <summary>Why the native app can't change it yet (its control is off), or null.</summary>
    public string? NotNative { get; init; }

    // the control is being set from the State: no change comes of it
    private bool _muted;

    /// <summary>The State line and the control after a change of State, Busy, Error or the Safe Mode waiting list
    /// (Set-AkariCatalogueCard): a change waiting for Safe Mode shows what it will be.</summary>
    public void Update(SafeChange? pending = null)
    {
        if (Error.Length > 0)
        {
            StateLine.Text = $"Failed: {Error}";
            StateLine.SetResourceReference(TextBlock.ForegroundProperty, "Bad");
        }
        else
        {
            StateLine.Text = Catalogue.StateText(Tweak, State, Busy, pending is not null);
            StateLine.SetResourceReference(TextBlock.ForegroundProperty, pending is not null ? "Warn" : "Ter");
        }
        StateLine.Visibility = StateLine.Text.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        Control.IsEnabled = Busy == CatalogueBusy.None && NotNative is null;
        _muted = true;
        try
        {
            switch (Control)
            {
                case ToggleButton sw:
                    sw.IsChecked = pending is not null ? pending.Mode == TweakMode.Apply
                        : State switch { TweakState.Optimized => true, TweakState.Default => false, _ => null };
                    break;
                case ComboBox box:
                    var show = pending is null ? Current : pending.Value ?? (pending.Mode == TweakMode.Apply ? Tweak.Recommended : WindowsDefault);
                    var item = show is null ? null : box.Items.OfType<ComboBoxItem>().FirstOrDefault(i => RegistryEngine.Matches(show, i.Tag));
                    if (item is null) box.SelectedIndex = -1; else box.SelectedItem = item;
                    break;
            }
        }
        finally { _muted = false; }
    }

    /// <summary>A new card. Changed: the control was used (Apply or Revert, a Choice value other than Recommended).</summary>
    public static CatalogueCard Make(Tweak t, object? windowsDefault, Action<CatalogueCard, TweakMode, object?> changed)
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
                sw.Click += (_, _) => changed(entry!, sw.IsChecked == true ? TweakMode.Apply : TweakMode.Revert, null);
                ctl = sw;
                break;
            case TweakKind.Choice:
                var box = new ComboBox { Width = 220 };
                box.SetResourceReference(FrameworkElement.StyleProperty, "Combo");
                foreach (var c in t.Choices)
                {
                    var label = c.Label.Length > 0 ? c.Label : $"{c.Value}";
                    if (RegistryEngine.Matches(c.Value, t.Recommended)) label += " (Recommended)";
                    else if (RegistryEngine.Matches(c.Value, windowsDefault)) label += " (Windows default)";
                    box.Items.Add(new ComboBoxItem { Content = label, Tag = c.Value });
                }
                box.SelectionChanged += (_, _) =>
                {
                    if (entry!._muted || box.SelectedItem is not ComboBoxItem { Tag: var v }) return;
                    if (RegistryEngine.Matches(v, windowsDefault)) changed(entry, TweakMode.Revert, null);
                    else if (RegistryEngine.Matches(v, t.Recommended)) changed(entry, TweakMode.Apply, null);
                    else changed(entry, TweakMode.Apply, v);
                };
                ctl = box;
                break;
            default:
                var btn = new Button { Content = t.Button, MinWidth = 96 };
                btn.SetResourceReference(FrameworkElement.StyleProperty, "Btn");
                btn.Click += (_, _) => changed(entry!, TweakMode.Apply, null);
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
        entry = new CatalogueCard { Tweak = t, Card = card, Control = ctl, StateLine = line, NotNative = notNative, WindowsDefault = windowsDefault };
        return entry;
    }
}
