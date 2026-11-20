using System.Reflection;
using AkariOS.Core;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Shell;

/// <summary>
/// src/Assets' logos and app icons, built into the exe (resource names <c>Assets/…</c>): unpacked into a folder on first
/// use, once per version, so WinUI's images read them as files. A single-file publish has no Assets folder next to the
/// exe, so reading them from there found nothing.
/// </summary>
public sealed class AssetFiles(string folder)
{
    private static readonly Assembly Own = typeof(AssetFiles).Assembly;
    private static readonly Lazy<HashSet<string>> Names = new(() =>
        Own.GetManifestResourceNames().Where(n => n.StartsWith("Assets/", StringComparison.Ordinal)).ToHashSet(StringComparer.OrdinalIgnoreCase));

    /// <summary>The app's: %LOCALAPPDATA%\AkariOS.Native\Assets\&lt;version&gt;.</summary>
    public static AssetFiles Default { get; } = new(Path.Combine(AkariPaths.UserFolder, "Assets", AkariInfo.Version));

    public string Folder { get; } = folder;

    /// <summary>The app icons built in (file names under Assets/Apps).</summary>
    public static IReadOnlyList<string> Apps => Names.Value.Where(n => n.StartsWith("Assets/Apps/", StringComparison.OrdinalIgnoreCase))
        .Select(n => n["Assets/Apps/".Length..]).ToList();

    public static bool Has(string name) => Names.Value.Contains($"Assets/{name}");

    /// <summary>The file of an asset ("AkariLogo-dark.png", "Apps/MSTeams.png"), unpacked when it isn't yet; null when
    /// there is no such asset or it can't be written.</summary>
    public string? File(string name)
    {
        if (!Has(name)) return null;
        var path = Path.Combine(Folder, name.Replace('/', Path.DirectorySeparatorChar));
        if (System.IO.File.Exists(path)) return path;
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            using var from = Own.GetManifestResourceStream(Names.Value.First(n => string.Equals(n, $"Assets/{name}", StringComparison.OrdinalIgnoreCase)))!;
            var temp = path + ".tmp";
            using (var to = System.IO.File.Create(temp)) from.CopyTo(to);
            System.IO.File.Move(temp, path, overwrite: true);
            return path;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return null; }
    }
}

/// <summary>An app's icon: its image (a black-or-white one tinted in the text colour), or a glyph when it has none.</summary>
public sealed record AppIcon(Uri? Image, bool Mono, string Glyph)
{
    public bool IsColor => Image is not null && !Mono;
    public bool IsMono => Image is not null && Mono;
    public bool IsGlyph => Image is null;
}

/// <summary>
/// New-AkariAppIcon's choice: an installed Store app's own logo, else the bundled src/Assets/Apps icon (a .mono.png is a
/// mask), else a glyph (a feature: settings; anything else: an app box). A Store logo that is white only is a mask too
/// (Test-AkariWhiteLogo): it would vanish on the light theme.
/// </summary>
public sealed class AppIcons(AssetFiles assets)
{
    public const string FeatureGlyph = "";
    public const string AppGlyph = "";

    private readonly Dictionary<string, bool> _white = new(StringComparer.OrdinalIgnoreCase);

    public AppIcon Of(Tweak t, IReadOnlyDictionary<string, string>? logos)
    {
        var glyph = t.Group is "capability" or "feature" ? FeatureGlyph : AppGlyph;
        var file = AppLists.IconFile(t, logos, "Apps", f => AssetFiles.Has(f.Replace('\\', '/')));
        if (file is null) return new(null, false, glyph);
        var own = !file.StartsWith("Apps", StringComparison.Ordinal);
        var path = own ? file : assets.File(file.Replace('\\', '/'));
        if (path is null) return new(null, false, glyph);
        return new(new Uri(path), own ? IsWhite(path) : AppLists.IsMono(file), glyph);
    }

    /// <summary>A Store package by name (the ISO Builder's image apps, which have no Tweak): its own logo, else the
    /// bundled icon named after it, else the app box.</summary>
    public AppIcon OfPackage(string package, IReadOnlyDictionary<string, string>? logos)
    {
        if (logos is not null && logos.TryGetValue(package, out var own) && System.IO.File.Exists(own))
            return new(new Uri(own), IsWhite(own), AppGlyph);
        foreach (var f in new[] { $"Apps/{package}.png", $"Apps/{package}.mono.png" })
            if (AssetFiles.Has(f) && assets.File(f) is { } path) return new(new Uri(path), AppLists.IsMono(f), AppGlyph);
        return new(null, false, AppGlyph);
    }

    private bool IsWhite(string file)
    {
        if (_white.TryGetValue(file, out var w)) return w;
        try
        {
            using var b = new System.Drawing.Bitmap(file);
            var px = new byte[b.Width * b.Height * 4];
            for (var y = 0; y < b.Height; y++)
                for (var x = 0; x < b.Width; x++)
                {
                    var c = b.GetPixel(x, y);
                    var i = (y * b.Width + x) * 4;
                    (px[i], px[i + 1], px[i + 2], px[i + 3]) = (c.B, c.G, c.R, c.A);
                }
            w = IsWhite(px, b.Width, b.Height);
        }
        catch (Exception e) when (e is ArgumentException or IOException or InvalidOperationException or OutOfMemoryException) { w = false; }
        return _white[file] = w;
    }

    /// <summary>Test-AkariWhiteLogo: the visible pixels (BGRA) are white or near white, no colour. Every second pixel of
    /// each second row.</summary>
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
