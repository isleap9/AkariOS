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
        SizeChanged += (_, e) => Layout(e.NewSize.Width);
    }

    // under 600 px the chooser's tiles and the count cards go one under the other (Home's rule)
    private void Layout(double width)
    {
        var narrow = width < 600;
        // Review's columns: the apps beside the Tweaks, or the apps above them under 800 px
        var stacked = width < 800;
        ReviewColumns.ColumnDefinitions[1].Width = stacked ? new GridLength(0) : new GridLength(1.3, GridUnitType.Star);
        ReviewColumns.ColumnSpacing = stacked ? 0 : 12;
        Grid.SetColumn(ReviewMainList, stacked ? 0 : 1);
        Grid.SetRow(ReviewMainList, stacked ? 1 : 0);
        foreach (var grid in new[] { Tiles, ReviewCounts, ResultCounts })
        {
            var n = grid.Children.Count;
            grid.ColumnDefinitions.Clear();
            grid.RowDefinitions.Clear();
            for (var i = 0; i < n; i++)
            {
                if (narrow) grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                else grid.ColumnDefinitions.Add(new ColumnDefinition());
            }
            for (var i = 0; i < n; i++)
            {
                var child = (FrameworkElement)grid.Children[i];
                Grid.SetColumn(child, narrow ? 0 : i);
                Grid.SetRow(child, narrow ? i : 0);
            }
        }
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

    // the hairlines of the run page's and Review's rows (page D): under every row but the last
    private void OnLinedRowPrepared(ItemsRepeater sender, ItemsRepeaterElementPreparedEventArgs args)
    {
        SetLine(sender, args.Element, args.Index);
        // a row added at the end: the one above it was the last and had no line
        if (args.Index > 0 && sender.TryGetElement(args.Index - 1) is { } above) SetLine(sender, above, args.Index - 1);
    }

    private void OnLinedRowMoved(ItemsRepeater sender, ItemsRepeaterElementIndexChangedEventArgs args) => SetLine(sender, args.Element, args.NewIndex);

    private static void SetLine(ItemsRepeater list, UIElement row, int index)
    {
        if (row is not Grid grid) return;
        var last = (list.ItemsSourceView?.Count ?? 0) - 1;
        grid.BorderThickness = new Thickness(0, 0, 0, index < last ? 1 : 0);
    }

    private void OnRemoveApps(object sender, RoutedEventArgs e) => ViewModel.OpenRemoveAppsCommand.Execute(null);

    private void OnOpenLog(object sender, RoutedEventArgs e) => ViewModel.OpenLogCommand.Execute(null);
}
