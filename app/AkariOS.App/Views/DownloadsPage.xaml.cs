using System.ComponentModel;
using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>Downloads, from <see cref="DownloadsViewModel"/>: Windows apps and External apps. The view fills the three
/// SelectorBars (the sections, the Windows lists, the categories) and keeps them in step; everything else is bound.</summary>
public sealed partial class DownloadsPage : Page
{
    private bool _filling;

    public DownloadsViewModel ViewModel { get; }

    public DownloadsPage(DownloadsViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        Sections.Items.Add(new SelectorBarItem { Text = "Windows apps", Tag = DownloadsViewModel.WindowsSection });
        Sections.Items.Add(new SelectorBarItem { Text = "External apps", Tag = DownloadsViewModel.ExternalSection });
        foreach (var name in AppsStepViewModel.RemoveLists) WinLists.Items.Add(new SelectorBarItem { Text = name, Tag = name });
        foreach (var c in viewModel.Categories)
        {
            var item = new SelectorBarItem { Text = c, Tag = c };
            Categories.Items.Add(item);
            if (c == viewModel.Category) Categories.SelectedItem = item;
        }
        ViewModel.PropertyChanged += OnViewModel;
        ViewModel.Windows.PropertyChanged += OnWindows;
        SizeChanged += (_, e) => Layout(e.NewSize.Width);
        Loaded += (_, _) =>
        {
            Sync();
            ViewModel.Open();
        };
        Unloaded += (_, _) =>
        {
            ViewModel.PropertyChanged -= OnViewModel;
            ViewModel.Windows.PropertyChanged -= OnWindows;
        };
    }

    // the section set by the navigation (Remove apps opens Windows apps), the lists read again after a removal
    private void OnViewModel(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(DownloadsViewModel.Section)) Sync();
    }

    private void OnWindows(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(RemoveAppsViewModel.Apps)) Sync();
    }

    private void Sync()
    {
        _filling = true;
        Sections.SelectedItem = Sections.Items.FirstOrDefault(i => (string)i.Tag == ViewModel.Section);
        WinLists.SelectedItem = WinLists.Items.FirstOrDefault(i => (string)i.Tag == ViewModel.Windows.Apps.RemoveList);
        _filling = false;
        Aurora.Palette = ViewModel.IsWindows ? "Remove" : "Downloads";
    }

    // narrow: the picks alone on the first row, Only installed, the count and Remove (n) under them; the search under
    // the categories
    private void Layout(double width)
    {
        var narrow = width < 800;
        Grid.SetColumnSpan(WinPicks, narrow ? 4 : 1);
        Grid.SetRow(WinOnly, narrow ? 1 : 0);
        Grid.SetColumn(WinOnly, narrow ? 0 : 1);
        WinOnly.Margin = narrow ? new Microsoft.UI.Xaml.Thickness(0) : new Microsoft.UI.Xaml.Thickness(8, 0, 0, 0);
        Grid.SetColumnSpan(WinOnly, narrow ? 2 : 1);
        Grid.SetRow(WinCount, narrow ? 1 : 0);
        Grid.SetRow(WinRemove, narrow ? 1 : 0);
        Grid.SetRow(ExtSearch, narrow ? 1 : 0);
        Grid.SetColumn(ExtSearch, narrow ? 0 : 1);
        ExtSearch.HorizontalAlignment = narrow ? Microsoft.UI.Xaml.HorizontalAlignment.Left : Microsoft.UI.Xaml.HorizontalAlignment.Stretch;
    }

    private void OnSection(SelectorBar sender, SelectorBarSelectionChangedEventArgs args)
    {
        if (!_filling && sender.SelectedItem?.Tag is string s) ViewModel.Section = s;
    }

    private void OnWinList(SelectorBar sender, SelectorBarSelectionChangedEventArgs args)
    {
        if (!_filling && sender.SelectedItem?.Tag is string name) ViewModel.Windows.Apps.RemoveList = name;
    }

    // a click anywhere on a card (it is a button) picks it; the Install, "…" and box buttons inside it handle their own
    // click. Windows apps: an installed app's "Remove" tick; External apps: picked for Install (n)
    private void OnCardClick(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        switch ((sender as Microsoft.UI.Xaml.FrameworkElement)?.DataContext)
        {
            case AppRowViewModel row when row.Installed: row.IsChecked = !row.IsChecked; break;
            case AppCardViewModel card when card.CanSelect: card.IsSelected = !card.IsSelected; break;
        }
    }

    private void OnCategory(SelectorBar sender, SelectorBarSelectionChangedEventArgs args)
    {
        if (sender.SelectedItem?.Tag is string c) ViewModel.Category = c;
    }
}
