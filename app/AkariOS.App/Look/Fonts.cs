using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace AkariOS.App.Look;

/// <summary>
/// The logos shipped in the exe (src/Assets). The fonts are Windows' own, resources of the shared Controls.xaml
/// (FontDisplay, FontText, FontSmall, FontMono; ADR 0008).
/// </summary>
public static class Assets
{
    public const string Base = "pack://application:,,,/AkariOS-Native;component/Assets/";

    /// <summary>The title bar's A mark for a theme: white on dark, black on light.</summary>
    public static Uri LogoFor(string theme) => new(Base + $"AkariLogo-{theme.ToLowerInvariant()}.png");

    public static Uri Icon => new(Base + "AkariLogo.ico");

    public static ImageSource Image(Uri uri)
    {
        var bmp = new BitmapImage();
        bmp.BeginInit();
        bmp.UriSource = uri;
        bmp.CacheOption = BitmapCacheOption.OnLoad;
        bmp.EndInit();
        bmp.Freeze();
        return bmp;
    }
}
