using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>
/// Install AkariOS: the chooser, Guided's steps, the run page and the result, all from <see cref="InstallViewModel"/>.
/// The view only fills the Quick select menus, hands a typed Choice value over, and lets a whole install card tick.
/// </summary>
public sealed partial class InstallPage : Page
{
    public InstallViewModel ViewModel { get; }

    public InstallPage(InstallViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        Loaded += (_, _) => ViewModel.Shown();
    }

    // the prototype's role="checkbox": a click anywhere on an install card ticks it (the box itself handles its own)
    private void OnInstallCard(object sender, Microsoft.UI.Xaml.Input.TappedRoutedEventArgs e)
    {
        if (e.OriginalSource is DependencyObject d && IsInCheckBox(d)) return;
        if (sender is FrameworkElement { DataContext: AppRowViewModel row }) row.IsChecked = !row.IsChecked;
    }

    private static bool IsInCheckBox(DependencyObject d)
    {
        for (var x = d; x is not null; x = Microsoft.UI.Xaml.Media.VisualTreeHelper.GetParent(x))
            if (x is CheckBox) return true;
        return false;
    }

    // the presets, built each time it opens (a preset saved just now is listed)
    private void OnQuickMenu(object sender, object e)
    {
        var menu = (MenuFlyout)sender;
        menu.Items.Clear();
        foreach (var p in ViewModel.Tweaks.Presets())
        {
            var item = new MenuFlyoutItem { Text = TweaksStepViewModel.PresetLabel(p) };
            if (p.Description.Length > 0) ToolTipService.SetToolTip(item, p.Description);
            item.Click += (_, _) => ViewModel.QuickSelect(p);
            menu.Items.Add(item);
        }
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(new MenuFlyoutItem { Text = "Save current as preset…", Command = ViewModel.Tweaks.SavePresetCommand });
    }

    // an Editable Choice: the typed number becomes the row's value
    private void OnChoiceTyped(ComboBox sender, ComboBoxTextSubmittedEventArgs args)
    {
        if (sender.DataContext is not TweakRowViewModel row) return;
        row.Type(args.Text);
        args.Handled = true;
    }

    private void OnRemoveApps(object sender, RoutedEventArgs e) => ViewModel.OpenRemoveAppsCommand.Execute(null);

    private void OnOpenLog(object sender, RoutedEventArgs e) => ViewModel.OpenLogCommand.Execute(null);
}
