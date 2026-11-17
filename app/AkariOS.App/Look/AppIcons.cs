using System.Globalization;
using System.IO;
using System.Resources;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Look;

/// <summary>
/// The Apps step's 20 px icons (New-AkariAppIcon), all without a background: an installed Store app's own logo (a file
/// on the disk, AppPackages.Logos), else the bundled src/Assets/Apps/&lt;package or id&gt;.png or .mono.png (built into
/// the exe as WPF resources), else a muted Fluent icon. A black-or-white logo (a .mono.png mask, or a Store logo that
/// is white only) is drawn in the theme's text colour.
/// </summary>
public static class AppIcons
{
    private const string Dir = @"assets\apps";

    // the exe's WPF resources (AkariOS-Native.g), read as streams: no pack:// URI, which needs WPF's Application
    private static readonly ResourceManager Resources = new(typeof(AppIcons).Assembly.GetName().Name + ".g", typeof(AppIcons).Assembly);

    /// <summary>The bundled icons' file names (lowercase), read once from the exe's resources.</summary>
    public static IReadOnlySet<string> Bundled => _bundled.Value;

    private static readonly Lazy<IReadOnlySet<string>> _bundled = new(() =>
    {
        var set = Resources.GetResourceSet(CultureInfo.InvariantCulture, createIfNotExists: true, tryParents: true);
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (set is not null)
            foreach (System.Collections.DictionaryEntry e in set)
                if (e.Key is string k && k.StartsWith("assets/apps/", StringComparison.OrdinalIgnoreCase)) names.Add(k["assets/apps/".Length..]);
        return names;
    });

    /// <summary>Get-AkariAppIconFile on the bundled icons: the logo file, or assets\apps\&lt;name&gt; (bundled), or null.</summary>
    public static string? File(Tweak t, IReadOnlyDictionary<string, string>? logos) =>
        AppLists.IconFile(t, logos, Dir, f => Bundled.Contains(System.IO.Path.GetFileName(f)));

    /// <summary>The Fluent icon of a row without an image: a feature's settings, else an app window.</summary>
    public static string Fallback(Tweak t) => t.Group is "capability" or "feature" ? "settings-2" : "app-window";

    /// <summary>The row's icon.</summary>
    public static FrameworkElement Make(Tweak t, IReadOnlyDictionary<string, string>? logos)
    {
        FrameworkElement? icon = null;
        if (File(t, logos) is { } file)
        {
            try
            {
                var bundled = file.StartsWith(Dir + "\\", StringComparison.OrdinalIgnoreCase);
                using var stream = bundled ? Resources.GetStream($"assets/apps/{System.IO.Path.GetFileName(file).ToLowerInvariant()}", CultureInfo.InvariantCulture) : null;
                var bi = new BitmapImage();
                bi.BeginInit();
                if (stream is not null) bi.StreamSource = stream;
                else bi.UriSource = new Uri(file);
                bi.DecodePixelWidth = 40;
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.EndInit();
                bi.Freeze();
                var mono = bundled ? AppLists.IsMono(file) : IsWhite(bi);
                if (mono)
                {
                    var r = new Rectangle { OpacityMask = new ImageBrush(bi) };
                    r.SetResourceReference(Shape.FillProperty, "Tx");
                    icon = r;
                }
                else
                {
                    var img = new Image { Source = bi };
                    RenderOptions.SetBitmapScalingMode(img, BitmapScalingMode.HighQuality);
                    icon = img;
                }
                icon.Width = icon.Height = 20;
            }
            catch (Exception e) when (e is IOException or NotSupportedException or UriFormatException or InvalidOperationException or ArgumentException) { icon = null; }
        }
        icon ??= Icons.Make(Fallback(t), 18, "Mu");
        icon.HorizontalAlignment = HorizontalAlignment.Left;
        icon.VerticalAlignment = VerticalAlignment.Center;
        return icon;
    }

    private static bool IsWhite(BitmapSource image)
    {
        var b = new FormatConvertedBitmap(image, PixelFormats.Bgra32, null, 0);
        var px = new byte[b.PixelWidth * b.PixelHeight * 4];
        b.CopyPixels(px, b.PixelWidth * 4, 0);
        return IsWhite(px, b.PixelWidth, b.PixelHeight);
    }

    /// <summary>Test-AkariWhiteLogo: the visible pixels (BGRA) are white or near white, no colour (it would vanish on
    /// the light theme). Every second pixel of each second row.</summary>
    public static bool IsWhite(byte[] bgra, int width, int height)
    {
        int n = 0, white = 0;
        for (var y = 0; y < height; y += 2)
            for (var x = 0; x < width; x += 2)
            {
                var i = (y * width + x) * 4;
                if (bgra[i + 3] < 100) continue;
                n++;
                var lo = Math.Min(bgra[i], Math.Min(bgra[i + 1], bgra[i + 2]));
                var hi = Math.Max(bgra[i], Math.Max(bgra[i + 1], bgra[i + 2]));
                if (lo >= 200 && hi - lo <= 30) white++;
            }
        return n > 0 && (double)white / n >= 0.9;
    }
}
