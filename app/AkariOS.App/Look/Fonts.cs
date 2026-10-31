using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace AkariOS.App.Look;

/// <summary>
/// The fonts and logos shipped in the exe (src/Assets, ADR 0006): FontDisplay (Unbounded), FontText (Manrope),
/// FontMono (JetBrains Mono) as resources, each falling back to Windows' own, as Get-AkariFonts does.
/// </summary>
public static class Assets
{
    public const string Base = "pack://application:,,,/AkariOS-Native;component/Assets/";

    /// <summary>The font resource keys and their families (pure: the names, for tests).</summary>
    public static IReadOnlyDictionary<string, string> FontNames { get; } = new Dictionary<string, string>
    {
        ["FontDisplay"] = "./#Unbounded, Segoe UI Variable Display, Segoe UI",
        ["FontText"] = "./#Manrope, Segoe UI Variable Text, Segoe UI",
        ["FontMono"] = "./#JetBrains Mono, Cascadia Mono, Consolas",
    };

    /// <summary>Puts FontDisplay, FontText and FontMono into the resources.</summary>
    public static void AddFonts(ResourceDictionary resources)
    {
        var baseUri = new Uri(Base + "Fonts/");
        foreach (var (key, family) in FontNames) resources[key] = new FontFamily(baseUri, family);
    }

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
