using Microsoft.UI.Xaml.Controls;
using AkariOS.App.ViewModels;

namespace AkariOS.App.Views;

public sealed partial class BuilderPage : Page
{
    public BuilderViewModel ViewModel { get; }

    public BuilderPage(BuilderViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }
}
