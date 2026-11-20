using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;

namespace AkariOS.App.Views;

/// <summary>Home. The view only picks the logo for the theme and lays out by width (Update-AkariHomeWidth): the tiles
/// one under the other under 600 px, the hero's facts gone under 760 px.</summary>
public sealed partial class HomePage : Page
{
    public HomeViewModel ViewModel { get; }

    public HomePage(HomeViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        Loaded += (_, _) => SetLogo();
        ActualThemeChanged += (_, _) => SetLogo();
        SizeChanged += (_, e) => Layout(e.NewSize.Width);
    }

    private void SetLogo()
    {
        var file = Path.Combine(AppContext.BaseDirectory, "Assets", ActualTheme == ElementTheme.Light ? "AkariLogo-light.png" : "AkariLogo-dark.png");
        HeroLogo.Source = File.Exists(file) ? new BitmapImage(new Uri(file)) : null;
    }

    private void Layout(double width)
    {
        Facts.Visibility = width < 760 ? Visibility.Collapsed : Visibility.Visible;
        var narrow = width < 600;
        Tiles.ColumnDefinitions.Clear();
        Tiles.RowDefinitions.Clear();
        for (var i = 0; i < 3; i++)
        {
            if (narrow) Tiles.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            else Tiles.ColumnDefinitions.Add(new ColumnDefinition());
        }
        for (var i = 0; i < Tiles.Children.Count; i++)
        {
            var tile = (FrameworkElement)Tiles.Children[i];
            Grid.SetColumn(tile, narrow ? 0 : i);
            Grid.SetRow(tile, narrow ? i : 0);
        }
    }
}
