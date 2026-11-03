using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;

namespace AkariOS.App.Pages;

/// <summary>
/// The Catalogue's two bars under the page (New-AkariCatalogueBar): Safe Mode changes waiting ("Restart and apply")
/// and the restarts the applied changes need ("Restart Explorer", "Restart now"). Shown on Catalogue pages only.
/// </summary>
public sealed class CatalogueBars
{
    public Border SafeBar { get; }
    public TextBlock SafeText { get; }
    public Button SafeApply { get; }
    public Border RestartBar { get; }
    public TextBlock RestartText { get; }
    public Button RestartExplorer { get; }
    public Button RestartPc { get; }

    public CatalogueBars(Action safeApply, Action restartExplorer, Action restartPc)
    {
        (SafeBar, SafeText, var safeButtons) = Bar("shield", "Warn");
        SafeApply = Parts.Button("Restart and apply", "Accent", safeApply);
        SafeApply.Margin = new Thickness(0);
        safeButtons.Children.Add(SafeApply);
        (RestartBar, RestartText, var restartButtons) = Bar("rotate-ccw", "Mu");
        RestartExplorer = Parts.Button("Restart Explorer", click: restartExplorer);
        RestartExplorer.Margin = new Thickness(0);
        RestartPc = Parts.Button("Restart now", click: restartPc);
        restartButtons.Children.Add(RestartExplorer);
        restartButtons.Children.Add(RestartPc);
    }

    /// <summary>Update-AkariCatalogueBars: the bars with something to say, in the panel when on a Catalogue page. A
    /// bar that appears rises into place.</summary>
    public void Update(Panel? host, bool on, int safe, IReadOnlyList<string> restart, bool explorer, bool reboot)
    {
        if (host is null) return;
        if (!host.Children.Contains(SafeBar)) { host.Children.Add(SafeBar); host.Children.Add(RestartBar); }
        Set(SafeBar, on && safe > 0);
        SafeText.Text = Core.Tweaks.Catalogue.SafeBarText(safe);
        Set(RestartBar, on && restart.Count > 0);
        RestartText.Text = string.Join("\n", restart);
        RestartExplorer.Visibility = explorer ? Visibility.Visible : Visibility.Collapsed;
        RestartPc.Visibility = reboot ? Visibility.Visible : Visibility.Collapsed;
        RestartPc.Margin = new Thickness(explorer ? 8 : 0, 0, 0, 0);
        host.Visibility = on && (safe > 0 || restart.Count > 0) ? Visibility.Visible : Visibility.Collapsed;
    }

    private static void Set(UIElement bar, bool show)
    {
        if (!show) bar.Visibility = Visibility.Collapsed;
        else if (bar.Visibility != Visibility.Visible) Motion.Show(bar, 8);
    }

    private static (Border, TextBlock, StackPanel) Bar(string icon, string brush)
    {
        var b = new Border { BorderThickness = new Thickness(0, 1, 0, 0), Padding = new Thickness(24, 10, 24, 10), Visibility = Visibility.Collapsed };
        b.SetResourceReference(Border.BorderBrushProperty, "Bd");
        b.SetResourceReference(Border.BackgroundProperty, "S1");
        var dp = new DockPanel();
        var ic = Icons.Make(icon, 18, brush);
        ic.Margin = new Thickness(0, 0, 12, 0);
        ic.VerticalAlignment = VerticalAlignment.Center;
        DockPanel.SetDock(ic, Dock.Left);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal };
        DockPanel.SetDock(buttons, Dock.Right);
        var text = Parts.Text("", 13);
        text.VerticalAlignment = VerticalAlignment.Center;
        dp.Children.Add(ic);
        dp.Children.Add(buttons);
        dp.Children.Add(text);
        b.Child = dp;
        return (b, text, buttons);
    }
}
