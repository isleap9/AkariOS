using AkariOS.App.ViewModels;
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
    }
}
