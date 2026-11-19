using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;

namespace AkariOS.App.Look;

/// <summary>
/// The small parts every page is made of (New-AkariText, New-AkariBlob, New-AkariLink, New-AkariModeCard, the
/// About cards): theme brushes by key, the shared fonts, the shared styles.
/// </summary>
public static class Parts
{
    /// <summary>Wrapping text in a theme brush.</summary>
    public static TextBlock Text(string text, double size = 13, string brush = "Tx")
    {
        var t = new TextBlock { Text = text, FontSize = size, TextWrapping = TextWrapping.Wrap };
        t.SetResourceReference(TextBlock.ForegroundProperty, brush);
        return t;
    }

    /// <summary>A heading in Unbounded (Display).</summary>
    public static TextBlock Title(string text, double size = 20, FontWeight? weight = null)
    {
        var t = Text(text, size);
        t.FontWeight = weight ?? FontWeights.SemiBold;
        t.SetResourceReference(TextElement.FontFamilyProperty, "FontDisplay");
        return t;
    }

    /// <summary>An icon on a rounded AccSoft square (New-AkariBlob).</summary>
    public static Border Blob(string icon, double size = 36, string brush = "AccText", string fill = "AccSoft")
    {
        var i = Icons.Make(icon, Math.Round(size * 0.55), brush);
        i.HorizontalAlignment = HorizontalAlignment.Center;
        i.VerticalAlignment = VerticalAlignment.Center;
        var b = new Border { Width = size, Height = size, CornerRadius = new CornerRadius(Math.Round(size * 0.3)), VerticalAlignment = VerticalAlignment.Center, Child = i, Tag = icon };
        b.SetResourceReference(Border.BackgroundProperty, fill);
        return b;
    }

    /// <summary>A button in a shared style (Btn, BtnP, Accent, Ghost).</summary>
    public static Button Button(string text, string style = "Btn", Action? click = null)
    {
        var b = new Button { Content = text, Margin = new Thickness(0, 0, 8, 0) };
        b.SetResourceReference(FrameworkElement.StyleProperty, style);
        if (click != null) b.Click += (_, _) => click();
        return b;
    }

    /// <summary>A text link (white, underlined on hover) that calls open with its URL.</summary>
    public static TextBlock Link(string text, string url, Action<string> open)
    {
        var tb = Text("", 13);
        var h = new Hyperlink(new Run(text)) { NavigateUri = new Uri(url), ToolTip = url, TextDecorations = null };
        h.SetResourceReference(TextElement.ForegroundProperty, "Tx");
        h.MouseEnter += (_, _) => h.TextDecorations = TextDecorations.Underline;
        h.MouseLeave += (_, _) => h.TextDecorations = null;
        h.RequestNavigate += (_, e) => { open(e.Uri.AbsoluteUri); e.Handled = true; };
        tb.Inlines.Add(h);
        return tb;
    }

    /// <summary>A poster card (New-AkariModeCard): blob, title, text; Hot = the recommended one (crimson border, glow).</summary>
    public static Button ModeCard(string icon, string title, string text, bool enabled = true, bool hot = false)
    {
        var b = new Button { IsEnabled = enabled };
        b.SetResourceReference(FrameworkElement.StyleProperty, hot ? "ModeCardHot" : "ModeCard");
        var sp = new StackPanel();
        var ic = Blob(icon, 48);
        ic.HorizontalAlignment = HorizontalAlignment.Left;
        ic.Margin = new Thickness(0, 0, 0, 16);
        sp.Children.Add(ic);
        sp.Children.Add(Title(title, 20));
        var tx = Text(text, 14, "Mu");
        tx.Margin = new Thickness(0, 8, 0, 0);
        sp.Children.Add(tx);
        b.Content = sp;
        b.Tag = title;
        return b;
    }

    /// <summary>A badge (New-AkariBadge): AkariOS (crimson tint), Caution (amber outline), Advanced (amber fill).</summary>
    public static Border Badge(string kind)
    {
        var (fg, bg, bd) = kind switch
        {
            "AkariOS" => ("AccText", "AccSoft", null),
            "Caution" => ("Warn", "WarnSoft", "Warn"),
            _ => ("WarnT", "Warn", (string?)null),
        };
        var b = new Border { CornerRadius = new CornerRadius(10), Padding = new Thickness(8, 1, 8, 2), Margin = new Thickness(0, 0, 6, 0), VerticalAlignment = VerticalAlignment.Center, Tag = kind };
        b.SetResourceReference(Border.BackgroundProperty, bg);
        if (bd is not null) { b.BorderThickness = new Thickness(1); b.SetResourceReference(Border.BorderBrushProperty, bd); }
        var t = new TextBlock { Text = kind, FontSize = 12, FontWeight = FontWeights.SemiBold };
        t.SetResourceReference(TextBlock.ForegroundProperty, fg);
        b.Child = t;
        return b;
    }

    /// <summary>A 14 px mark with a tooltip (New-AkariGlyph): restart required, Safe Mode.</summary>
    public static FrameworkElement Glyph(string icon, string brush, string tip)
    {
        var g = Icons.Make(icon, 14, brush);
        g.Margin = new Thickness(6, 0, 0, 0);
        g.VerticalAlignment = VerticalAlignment.Center;
        g.ToolTip = tip;
        return g;
    }

    /// <summary>A card with a title (the About cards): the card and the panel its body goes in.</summary>
    public static (Border Card, StackPanel Body) Card(string title)
    {
        var c = new Border { Margin = new Thickness(0, 0, 0, 12) };
        c.SetResourceReference(FrameworkElement.StyleProperty, "SettingCard");
        var sp = new StackPanel();
        var h = Title(title, 20);
        h.Margin = new Thickness(0, 0, 0, 10);
        sp.Children.Add(h);
        c.Child = sp;
        return (c, sp);
    }
}
