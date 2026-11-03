using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Shapes;

namespace AkariOS.App.Look;

/// <summary>Lucide icons from src/UI/Icons.xaml (New-AkariIcon): a 24x24 Path, stroke 2, round caps, in a Viewbox.</summary>
public static class Icons
{
    /// <summary>An icon in a theme brush, or "Inherit" = the surrounding control's text colour.</summary>
    public static Viewbox Make(string name, double size = 16, string brush = "Tx")
    {
        var p = new Path { StrokeThickness = 2, StrokeStartLineCap = PenLineCap.Round, StrokeEndLineCap = PenLineCap.Round, StrokeLineJoin = PenLineJoin.Round };
        p.SetResourceReference(Path.DataProperty, $"Ic.{name}");
        if (brush == "Inherit")
            p.SetBinding(Shape.StrokeProperty, new Binding("Foreground") { RelativeSource = new RelativeSource(RelativeSourceMode.FindAncestor, typeof(Control), 1) });
        else p.SetResourceReference(Shape.StrokeProperty, brush);
        var c = new Canvas { Width = 24, Height = 24 };
        c.Children.Add(p);
        return new Viewbox { Width = size, Height = size, Child = c, Tag = name };
    }

    /// <summary>A Category's icon ($AkariCategoryGlyphs, src/UI/Cards.ps1); settings for the others.</summary>
    public static IReadOnlyDictionary<string, string> Categories { get; } = new Dictionary<string, string>
    {
        ["Gaming"] = "gamepad-2", ["Performance"] = "gauge", ["Tuning"] = "sliders-vertical", ["Privacy"] = "lock",
        ["Check"] = "activity", ["Refresh"] = "refresh-cw", ["Setup"] = "wrench", ["Graphics"] = "monitor",
        ["Windows"] = "app-window", ["Hardware"] = "cpu", ["Advanced"] = "flask-conical",
        ["Taskbar"] = "panel-bottom", ["Start"] = "layout-grid", ["Explorer"] = "folder", ["Theme"] = "palette",
        ["Update"] = "cloud-download", ["Power"] = "power", ["Network"] = "wifi", ["Notifications"] = "bell", ["Input"] = "mouse",
        ["Accessibility"] = "accessibility", ["Sound"] = "volume-2", ["System"] = "settings-2",
        ["Security"] = "shield-check", ["Display"] = "monitor", ["Apps"] = "app-window", ["Cleanup"] = "eraser", ["Drivers"] = "hard-drive",
        ["Context menu"] = "menu", ["Services"] = "activity", ["Scheduled tasks"] = "history",
    };

    public static string Category(string category) => Categories.GetValueOrDefault(category) ?? "settings";

    /// <summary>Points an icon (a Viewbox from Make, or a Path in XAML) at another icon.</summary>
    public static void Set(FrameworkElement icon, string name)
    {
        var p = icon as Path ?? (Path)((Canvas)((Viewbox)icon).Child).Children[0];
        p.SetResourceReference(Path.DataProperty, $"Ic.{name}");
        icon.Tag = name;
    }
}
