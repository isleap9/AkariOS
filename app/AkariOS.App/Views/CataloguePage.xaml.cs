using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>
/// A Catalogue page: the bars, the Categories' SelectorBar (picking one scrolls to it), the cards. Search results
/// have no SelectorBar. Built from <see cref="CataloguePageViewModel"/>; the view only scrolls.
/// </summary>
public sealed partial class CataloguePage : Page
{
    private bool _filling;

    public CataloguePageViewModel ViewModel { get; }

    public CataloguePage(CataloguePageViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        // FrameNavigationService hands the query to the view model after the page is made: fill once it is loaded
        Loaded += (_, _) => Fill();
    }

    private void Fill()
    {
        _filling = true;
        Categories.Items.Clear();
        Categories.Visibility = ViewModel.IsSearch || ViewModel.Groups.Count < 2 ? Visibility.Collapsed : Visibility.Visible;
        if (!ViewModel.IsSearch)
            foreach (var g in ViewModel.Groups)
                Categories.Items.Add(new SelectorBarItem { Text = g.Title, Tag = g.Key });
        var start = Categories.Items.FirstOrDefault(i => (string)i.Tag == ViewModel.ScrollTo) ?? Categories.Items.FirstOrDefault();
        if (start is not null) Categories.SelectedItem = start;
        _filling = false;
        if (ViewModel.ScrollTo.Length > 0)
            DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () => ScrollTo(ViewModel.ScrollTo, animate: false));
    }

    private void OnCategoryPicked(SelectorBar sender, SelectorBarSelectionChangedEventArgs args)
    {
        if (!_filling && sender.SelectedItem?.Tag is string key) ScrollTo(key, animate: true);
    }

    private void ScrollTo(string key, bool animate)
    {
        var i = ViewModel.Groups.ToList().FindIndex(g => g.Key == key);
        if (i < 0 || GroupList.ContainerFromIndex(i) is not UIElement e) return;
        e.StartBringIntoView(new BringIntoViewOptions { VerticalAlignmentRatio = 0, VerticalOffset = -8, AnimationDesired = animate });
    }
}
