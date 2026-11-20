using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

public sealed partial class PlaceholderPage : Page
{
    public PlaceholderViewModel ViewModel { get; }

    public PlaceholderPage(PlaceholderViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        DataContext = viewModel;
    }
}
