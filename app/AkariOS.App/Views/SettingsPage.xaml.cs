using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;

namespace AkariOS.App.Views;

public sealed partial class SettingsPage : Page
{
    public SettingsViewModel ViewModel { get; }

    public SettingsPage(SettingsViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        Loaded += (_, _) => SetLogo();
        ActualThemeChanged += (_, _) => SetLogo();
    }

    // a link: its Url in the Tag (opened through IShellOpen: http / https only)
    private void OnLink(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string url }) ViewModel.OpenLinkCommand.Execute(url);
    }

    private void SetLogo()
    {
        var file = Shell.AssetFiles.Default.File(ActualTheme == ElementTheme.Light ? "AkariLogo-light.png" : "AkariLogo-dark.png");
        AboutLogo.Source = file is null ? null : new BitmapImage(new Uri(file));
    }
}
