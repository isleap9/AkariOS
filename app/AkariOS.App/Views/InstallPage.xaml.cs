using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>
/// Install AkariOS: the chooser, Guided's steps, the run page and the result, all from <see cref="InstallViewModel"/>.
/// The view only fills the Quick select menus, hands the Apps tabs and a typed Choice value over, and sets the Tweaks
/// step's columns by its width (three from 900 px).
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
        Column.SizeChanged += (_, e) => ViewModel.Tweaks.SetColumns(e.NewSize.Width >= 900 ? 3 : 2);
        ViewModel.PropertyChanged += (_, e) =>
        {
            // a new Tweaks step (Done, a Reset): its columns for this width
            if (e.PropertyName == nameof(InstallViewModel.Tweaks)) ViewModel.Tweaks.SetColumns(Column.ActualWidth >= 900 ? 3 : 2);
            if (e.PropertyName == nameof(InstallViewModel.Apps)) AppTabs.SelectedItem = AppTabs.Items[0];
        };
    }

    private void OnAppTab(SelectorBar sender, SelectorBarSelectionChangedEventArgs args)
    {
        if (sender.SelectedItem?.Tag is string tab) ViewModel.Apps.ShowTab(tab);
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
