using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;

namespace AkariOS.App.Views;

/// <summary>
/// A Catalogue page (<see cref="CataloguePageViewModel"/>): a Section's Categories as rows, a Category's cards, or the
/// search's results. The view only flashes a suggestion's card.
/// </summary>
public sealed partial class CataloguePage : Page
{
    public CataloguePageViewModel ViewModel { get; }

    public CataloguePage(CataloguePageViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        // FrameNavigationService hands the query to the view model after the page is made: once it is loaded
        Loaded += (_, _) =>
        {
            if (ViewModel.Flash.Length > 0)
                DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () => FlashCard(ViewModel.Flash));
        };
    }

    private void OnCategoryCard(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string key }) ViewModel.OpenCategory(key);
    }

    // Open-AkariSuggestion: the suggested Tweak's card in the middle of the view, dimmed and back twice
    private void FlashCard(string id)
    {
        if (Find(GroupList, id) is not { } card) return;
        card.StartBringIntoView(new BringIntoViewOptions { VerticalAlignmentRatio = 0.5, AnimationDesired = true });
        var fade = new DoubleAnimationUsingKeyFrames { Duration = TimeSpan.FromMilliseconds(1000) };
        foreach (var (ms, v) in new[] { (0, 1.0), (250, 0.35), (500, 1.0), (750, 0.35), (1000, 1.0) })
            fade.KeyFrames.Add(new LinearDoubleKeyFrame { KeyTime = TimeSpan.FromMilliseconds(ms), Value = v });
        Storyboard.SetTarget(fade, card);
        Storyboard.SetTargetProperty(fade, "Opacity");
        var story = new Storyboard();
        story.Children.Add(fade);
        story.Begin();
    }

    // the card whose view model is this Tweak's
    private static FrameworkElement? Find(DependencyObject root, string id)
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            if (child is Border { DataContext: TweakCardViewModel c } b && c.Id == id) return b;
            if (Find(child, id) is { } hit) return hit;
        }
        return null;
    }
}
