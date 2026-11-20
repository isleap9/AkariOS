using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>Remove apps, from <see cref="RemoveAppsViewModel"/>.</summary>
public sealed partial class RemoveAppsPage : Page
{
    public RemoveAppsViewModel ViewModel { get; }

    public RemoveAppsPage(RemoveAppsViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        Loaded += (_, _) => ViewModel.Shown();
    }

}
