using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Presets;

namespace AkariOS.App.Pages;

/// <summary>
/// Home (src/UI/MainWindow.xaml's HomePanel and Shell.ps1): no page header, the hero is its title (the version
/// overline, the headline, the lead, One-click and Choose changes, three stats), then MORE TOOLS: the mode cards.
/// </summary>
public static class HomePage
{
    /// <summary>The mode cards: icon, title, text, the page they open (null = a dialog says when it comes).</summary>
    public static IReadOnlyList<(string Icon, string Title, string Text, string? Page)> Tiles { get; } =
    [
        ("sliders-horizontal", "Optimize", "Manual, in-depth optimization for Windows. Recommended for power users.", "Optimize"),
        ("download", "Downloads", "Install apps, game launchers, runtimes and tools, or bring back Store apps the debloat removed.", "Downloads"),
        ("usb", "Unattend Generator", "Prepare a Windows install USB: an autounattend.xml with accounts, language, edition, disk and setup choices, after Schneegans' generator.", "Unattend Generator"),
        ("disc-3", "ISO Builder", "Build your own Windows 11 ISO: apps removed, updates, Defender and AI your way, AkariOS on the desktop. Downloads the ISO too.", "ISO Builder"),
        ("arrow-left-right", "Import / Export settings", "Save this PC's settings to a file, or load them on another PC and review them in Guided.", null),
    ];

    /// <summary>The three stats: Tweaks, removable apps, changes applied (a dash until read).</summary>
    public static IReadOnlyList<(string Key, string Label)> Stats { get; } = [("Tweaks", "Tweaks"), ("Apps", "Removable apps"), ("Applied", "Changes applied")];

    public static UIElement Build(AppServices s)
    {
        var root = new StackPanel();
        var hero = new StackPanel { Margin = new Thickness(8, 12, 8, 36) };
        var over = Parts.Title($"AKARIOS {AkariInfo.Version}", 11);
        over.SetResourceReference(TextBlock.ForegroundProperty, "AccText");
        over.Margin = new Thickness(0, 0, 0, 12);
        hero.Children.Add(over);
        hero.Children.Add(Parts.Title("Windows, tuned for games.", 40, FontWeights.Bold));
        var lead = Parts.Text("Remove the bloat, apply the tweaks that matter and keep a way back: every change can be reverted to the Windows default.", 16, "Mu");
        lead.MaxWidth = 620;
        lead.HorizontalAlignment = HorizontalAlignment.Left;
        lead.Margin = new Thickness(0, 12, 0, 0);
        hero.Children.Add(lead);

        var buttons = new WrapPanel { Margin = new Thickness(0, 24, 0, 0) };
        var oneClick = new Button { Margin = new Thickness(0, 0, 12, 8), ToolTip = "The full AkariOS setup in one go, with restarts handled for you" };
        oneClick.SetResourceReference(FrameworkElement.StyleProperty, "BtnP");
        var oc = new StackPanel { Orientation = Orientation.Horizontal };
        var zap = Icons.Make("zap", 16, "AccT");
        zap.Margin = new Thickness(0, 0, 8, 0);
        oc.Children.Add(zap);
        oc.Children.Add(new TextBlock { Text = "One-click setup" });
        oneClick.Content = oc;
        // One-click is a Run in phases across restarts (N7)
        oneClick.Click += (_, _) => s.NotYet("One-click", "N7");
        buttons.Children.Add(oneClick);
        var choose = Parts.Button("Choose changes", click: () => s.Shell.Open("Install AkariOS"));
        choose.Margin = new Thickness(0, 0, 0, 8);
        choose.ToolTip = "Pick the apps and Tweaks yourself, review them, then apply them in one go";
        buttons.Children.Add(choose);
        hero.Children.Add(buttons);

        var stats = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 28, 0, 0) };
        var numbers = new Dictionary<string, TextBlock>();
        foreach (var (key, label) in Stats)
        {
            if (stats.Children.Count > 0)
            {
                var rule = new Border { Width = 1, Margin = new Thickness(28, 6, 28, 6) };
                rule.SetResourceReference(Border.BackgroundProperty, "Bd");
                stats.Children.Add(rule);
            }
            var sp = new StackPanel();
            var n = Parts.Title("—", 28, FontWeights.Bold);
            sp.Children.Add(n);
            sp.Children.Add(Parts.Text(label, 13, "Mu"));
            stats.Children.Add(sp);
            numbers[key] = n;
        }
        hero.Children.Add(stats);
        root.Children.Add(hero);

        var more = Parts.Title("MORE TOOLS", 11);
        more.SetResourceReference(TextBlock.ForegroundProperty, "Mu");
        more.Margin = new Thickness(8, 0, 0, 12);
        root.Children.Add(more);
        // 16 px between cards in any number of columns: 8 around each, the grid pulled out by 8
        var grid = new UniformGrid { Columns = ShellLayout.HomeColumns(s.Shell.Width), Margin = new Thickness(-8) };
        foreach (var (icon, title, text, page) in Tiles)
        {
            var card = Parts.ModeCard(icon, title, text);
            card.Margin = new Thickness(8);
            card.Click += (_, _) => { if (page is null) s.NotYet(title, "N3"); else s.Shell.Open(page); };
            grid.Children.Add(card);
        }
        root.Children.Add(grid);
        void OnWidth(object? _, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(ShellViewModel.Width)) grid.Columns = ShellLayout.HomeColumns(s.Shell.Width);
        }
        s.Shell.PropertyChanged += OnWidth;
        root.Unloaded += (_, _) => s.Shell.PropertyChanged -= OnWidth;

        // the stats: Tweaks = the Catalogue's, at once; removable apps need the Store package reader (N5); changes
        // applied = what Export would save, read once in the background
        Motion.Count(numbers["Tweaks"], Catalogue.Tweaks(s.Engine.Loaded.Tweaks, s.Engine.System).Count);
        if (s.AppliedCount is { } applied) Motion.Count(numbers["Applied"], applied);
        else
            s.Background(() => PresetStore.ExportItems(s.Engine.Loaded.Tweaks, s.Engine.States, s.Engine.System).Count, r =>
            {
                if (r is int count) { s.AppliedCount = count; Motion.Count(numbers["Applied"], count); }
            });
        // the mode cards come in one after another the first time Home is shown
        if (!s.HomeShown) { s.HomeShown = true; Motion.Stagger(grid.Children.OfType<UIElement>()); }
        return root;
    }
}
