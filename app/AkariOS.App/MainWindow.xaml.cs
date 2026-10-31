using System.Windows;
using System.Windows.Media.Imaging;
using AkariOS.App.Look;

namespace AkariOS.App;

public partial class MainWindow : Window
{
    private readonly ThemeService _theme;

    public MainWindow(ThemeService theme)
    {
        InitializeComponent();
        _theme = theme;
        VersionText.Text = $"AkariOS {Core.AkariInfo.Version}";
        try { Icon = BitmapFrame.Create(Assets.Icon); } catch (Exception) { }
        // opens wide enough for the whole top bar (1360 x 800) when the screen has room, else as big as it allows
        var area = SystemParameters.WorkArea;
        Width = Math.Max(MinWidth, Math.Min(1360, area.Width - 40));
        Height = Math.Max(MinHeight, Math.Min(800, area.Height - 40));
        WindowFrame.Attach(this, Body, theme);
        theme.Changed += UpdateLogo;
        UpdateLogo();
        // maximized, Windows pushes the frame past the screen edge: pad it back in
        StateChanged += (_, _) => Shell.Margin = new Thickness(WindowState == WindowState.Maximized ? 8 : 0);
    }

    private void UpdateLogo()
    {
        try { Logo.Source = Assets.Image(Assets.LogoFor(_theme.Current)); } catch (Exception) { }
    }
}
