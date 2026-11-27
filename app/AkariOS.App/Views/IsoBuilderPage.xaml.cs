using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>The ISO Builder, from <see cref="IsoBuilderViewModel"/> (one per app: its picks stay while the page is
/// left and opened again).</summary>
public sealed partial class IsoBuilderPage : Page
{
    public IsoBuilderViewModel ViewModel { get; }

    public IsoBuilderPage(IsoBuilderViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        SizeChanged += (_, e) => Layout(e.NewSize.Width);
        Layout(0);
    }

    // wide: the side panel beside the step (its steps and image); under 1000 px the stepper and the image above it
    private void Layout(double width)
    {
        var narrow = width < 1000;
        Aside.Visibility = narrow ? Visibility.Collapsed : Visibility.Visible;
        NarrowSteps.Visibility = narrow ? Visibility.Visible : Visibility.Collapsed;
        Body.ColumnSpacing = narrow ? 0 : 16;
    }
}
