
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Shapes;
using AkariOS.App.Look;
using AkariOS.App.Pages;

namespace AkariOS.App.Shell;

/// <summary>
/// The title bar's options menu (src/UI/About.ps1, after Win11Debloat's): Import / Export settings, System Restore,
/// the theme (Follow Windows, Dark, Light), the About links, Logs, About. A row with no action is greyed out and says
/// when it comes.
/// </summary>
public static class OptionsMenu
{
    public static IReadOnlyDictionary<string, string> ThemeLabels { get; } = new Dictionary<string, string>
    {
        ["System"] = "Theme: Follow Windows", ["Dark"] = "Theme: Dark", ["Light"] = "Theme: Light",
    };

    private static readonly IReadOnlyDictionary<string, string> LinkIcons = new Dictionary<string, string>
    {
        ["GitHub"] = "github", ["Report a bug"] = "bug", ["Discord"] = "message-circle",
    };

    /// <summary>A menu row: an icon in the row's text colour and a label; no click = greyed, "Coming with ...".</summary>
    public static MenuItem Item(string header, string icon, Action<MenuItem>? click, string? comingWith = null)
    {
        var it = new MenuItem { Header = header };
        // the menu opens in a popup, outside the window's tree: the icon's shape comes from the app's resources and
        // its colour from the row
        var ic = Icons.Make(icon, 16);
        var p = (System.Windows.Shapes.Path)((Canvas)ic.Child).Children[0];
        if (Application.Current?.TryFindResource($"Ic.{icon}") is System.Windows.Media.Geometry g) p.Data = g;
        p.SetBinding(Shape.StrokeProperty, new Binding("Foreground") { Source = it });
        it.Icon = ic;
        if (click != null) it.Click += (_, _) => click(it);
        else
        {
            it.IsEnabled = false;
            it.ToolTip = comingWith is null ? "Coming in a later version" : $"Coming with {comingWith}";
            ToolTipService.SetShowOnDisabled(it, true);
        }
        return it;
    }

    public static ContextMenu Build(AppServices s)
    {
        // 220 px wide plus the 12 px shadow margin on each side, so it can be right-aligned when it opens
        var menu = new ContextMenu { Width = 244 };
        menu.Items.Add(Item("Import settings", "file-input", null, "N3"));
        menu.Items.Add(Item("Export settings", "file-output", null, "N3"));
        menu.Items.Add(Item("System Restore", "history", _ => s.Open.Program(System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "rstrui.exe"))));
        menu.Items.Add(Item(ThemeLabels[s.Theme.Setting], "sun-moon", it =>
        {
            var next = ThemeService.Next(s.Theme.Setting);
            s.Theme.Apply(next, save: true);
            it.Header = ThemeLabels[next];
        }));
        menu.Items.Add(new Separator());
        foreach (var (name, url) in AboutData.Read(s.Engine.Files).Links.Where(l => l.Url.Length > 0))
            menu.Items.Add(Item(name, LinkIcons.GetValueOrDefault(name, "external-link"), _ => s.Open.Url(url)));
        menu.Items.Add(Item("Logs", "folder-open", _ => s.Open.Folder(s.LogFolder)));
        menu.Items.Add(Item("About", "info", _ => s.Shell.Open("About")));
        return menu;
    }

    /// <summary>Opens the menu under the caption buttons, its right edge 4 px in from the window's.</summary>
    public static void Attach(Button button, ContextMenu menu)
    {
        button.ContextMenu = menu;
        button.Click += (_, _) =>
        {
            var caps = (FrameworkElement)button.Parent;
            menu.PlacementTarget = caps;
            menu.Placement = PlacementMode.Bottom;
            menu.HorizontalOffset = caps.ActualWidth - menu.Width + 12 - 4;
            menu.VerticalOffset = -12 + 4;
            menu.IsOpen = true;
        };
    }
}
