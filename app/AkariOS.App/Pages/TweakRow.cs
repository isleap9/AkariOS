using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Documents;
using AkariOS.App.Look;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>
/// One row of the Guided Tweaks step (New-AkariTweakRow, src/UI/Cards.ps1): a checkbox for a Toggle or Action, or
/// the name over a picker for a Choice (segmented for up to 4 values that can't be typed, else a dropdown), index 0
/// "No change"; Risk, restart and an unread State marked right of the name; the description in its tooltip.
/// </summary>
public sealed class TweakRow
{
    public required Tweak Tweak { get; init; }
    public required TweakState State { get; init; }
    public object? Current { get; init; }
    public object? WindowsDefault { get; init; }
    public required DockPanel Row { get; init; }
    public required Control Control { get; init; }

    /// <summary>Where the row started (Optimized / None, or a Choice value) and, for a Choice, what it shows now.</summary>
    public object Initial { get; set; } = Selection.None;
    public object Shown { get; set; } = Selection.None;

    // the control is being set by code: no change comes of it
    internal bool Muted;

    /// <summary>Puts the control on a target (Set-AkariRowControl): Optimized = checked, a Choice value, None.</summary>
    public void SetControl(object target)
    {
        Muted = true;
        try
        {
            if (Control is Selector pick)
            {
                var item = target as string == Selection.None ? null
                    : pick.Items.Cast<ContentControl>().Skip(1).FirstOrDefault(i => RegistryEngine.Matches(i.Tag, target));
                if (item is not null) pick.SelectedItem = item;
                else if (pick is ComboBox { IsEditable: true } box && target as string != Selection.None) { box.SelectedIndex = -1; box.Text = $"{target}"; }
                else pick.SelectedIndex = 0;
            }
            else ((CheckBox)Control).IsChecked = target as string == Selection.Optimized;
        }
        finally { Muted = false; }
    }

    /// <summary>The value picked or typed in a Choice row (Get-AkariComboValue): None for "No change", null when
    /// the typed text is not a number.</summary>
    public object? PickedValue()
    {
        var pick = (Selector)Control;
        var box = Control as ComboBox;
        if (pick.SelectedItem is ContentControl it && (box is not { IsEditable: true } || box.Text == it.Content as string))
            return pick.SelectedIndex == 0 ? Selection.None : it.Tag;
        if (box is { IsEditable: true })
            return box.Text.Trim().Length == 0 ? Selection.None : Selection.ParseNumber(box.Text);
        return Selection.None;
    }

    public static TweakRow Make(Tweak t, TweakState state, object? current, object? windowsDefault)
    {
        var glyphs = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        if (t.Risk is Risk.Caution or Risk.Advanced) glyphs.Children.Add(Parts.Glyph("triangle-alert", t.Risk == Risk.Advanced ? "Bad" : "Warn", t.Risk.ToString()));
        if (t.Reboot) glyphs.Children.Add(Parts.Glyph("rotate-ccw", "Mu", "Restart required"));
        if (t.Kind != TweakKind.Action && state is TweakState.Custom or TweakState.Unknown)
            glyphs.Children.Add(Parts.Glyph("circle-help", "Ter", state == TweakState.Custom ? "Custom value" : "State unknown"));
        var name = new TextBlock { FontSize = 13, TextWrapping = TextWrapping.Wrap, VerticalAlignment = VerticalAlignment.Center };
        name.Inlines.Add(new Run(t.Name));
        // part of the AkariOS setup (what One-click applies): "(AkariOS)" after the name, muted
        if (t.AkariOS)
        {
            var tag = new Run(" (AkariOS)");
            tag.SetResourceReference(TextElement.ForegroundProperty, "Mu");
            name.Inlines.Add(tag);
        }
        var row = new DockPanel { Margin = new Thickness(0, 4, 0, 4), ToolTip = Selection.RowTip(t, state), Tag = t.Id };
        DockPanel.SetDock(glyphs, Dock.Right);
        Control ctl;
        if (t.Kind == TweakKind.Choice)
        {
            // a ListBox for the segmented picker (a ComboBoxItem in a ListBox ignores clicks), each with its own items
            var segmented = !t.Editable && t.Choices.Count <= 4;
            Selector pick;
            if (segmented)
            {
                pick = new ListBox { HorizontalAlignment = HorizontalAlignment.Left };
                pick.SetResourceReference(FrameworkElement.StyleProperty, "Segmented");
            }
            else
            {
                pick = new ComboBox { IsEditable = t.Editable, HorizontalAlignment = HorizontalAlignment.Stretch };
                pick.SetResourceReference(FrameworkElement.StyleProperty, "Combo");
            }
            pick.Margin = new Thickness(0, 6, 0, 0);
            ContentControl Item(string label, object? tag) => segmented ? new ListBoxItem { Content = label, Tag = tag } : new ComboBoxItem { Content = label, Tag = tag };
            pick.Items.Add(Item("No change", null));
            foreach (var c in t.Choices)
            {
                var label = c.Label.Length > 0 ? c.Label : $"{c.Value}";
                if (RegistryEngine.Matches(c.Value, t.Recommended)) label += " (Recommended)";
                else if (RegistryEngine.Matches(c.Value, windowsDefault)) label += " (Windows default)";
                pick.Items.Add(Item(label, c.Value));
            }
            var head = new DockPanel();
            head.Children.Add(glyphs);
            head.Children.Add(name);
            var sp = new StackPanel();
            sp.Children.Add(head);
            sp.Children.Add(pick);
            row.Children.Add(sp);
            ctl = pick;
        }
        else
        {
            var box = new CheckBox { Content = name };
            box.SetResourceReference(FrameworkElement.StyleProperty, "Check");
            row.Children.Add(glyphs);
            row.Children.Add(box);
            ctl = box;
        }
        ctl.Tag = t.Id;
        return new TweakRow { Tweak = t, State = state, Current = current, WindowsDefault = windowsDefault, Row = row, Control = ctl };
    }
}
