using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>Optimize's overview, from <see cref="OptimizeViewModel"/>.</summary>
public sealed partial class OptimizePage : Page
{
    public OptimizeViewModel ViewModel { get; }

    public OptimizePage(OptimizeViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
    }

    private void OnSection(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string key }) ViewModel.Open(key);
    }
}
