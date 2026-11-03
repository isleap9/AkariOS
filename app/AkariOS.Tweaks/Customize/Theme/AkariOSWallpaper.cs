using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Theme;

/// <summary>src/Tweaks/Customize/Theme/AkariOSWallpaper.ps1: src/OneClick/img.jpg copied to Windows\Web\AkariOS, Fill,
/// set for the real user and shown now. Optimized = that copy is the wallpaper and the same size as the image (an older
/// AkariOS wallpaper reads Custom); Revert = Windows' own img0.jpg.</summary>
[TweakCode("theme-akarios-wallpaper")]
public sealed class AkariOSWallpaper : ITweakCode
{
    public const string Image = "src/OneClick/img.jpg";
    private const string Desktop = @"HKCU:\Control Panel\Desktop";
    private const string Wallpapers = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers";

    private static string Windows(TweakContext c) => TweakServices.Folder(c.Services.Windows, "Windows");
    private static string Ours(TweakContext c) => Path.Combine(Windows(c), @"Web\AkariOS\img.jpg");
    private static string Img0(TweakContext c) => Path.Combine(Windows(c), @"Web\Wallpaper\Windows\img0.jpg");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var w = PsSemantics.Text(c.Registry.GetValue(Desktop, "Wallpaper"));
        var dst = Ours(c);
        var same = File.Exists(dst) && c.Files.Exists(Image) && new FileInfo(dst).Length == c.Files.ReadBytes(Image).Length;
        if (string.Equals(w, dst, StringComparison.OrdinalIgnoreCase) && same) return TweakState.Optimized;
        return string.Equals(w, Img0(c), StringComparison.OrdinalIgnoreCase) ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        if (!c.Files.Exists(Image)) throw new InvalidOperationException($"the AkariOS wallpaper is missing: {Image}");
        var dst = Ours(c);
        Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
        File.WriteAllBytes(dst, c.Files.ReadBytes(Image));
        c.Registry.SetValue(Wallpapers, "BackgroundType", 0, "DWord");
        c.Registry.SetValue(Desktop, "WallpaperStyle", "10", "String");
        c.Registry.SetValue(Desktop, "TileWallpaper", "0", "String");
        c.Registry.SetValue(Desktop, "JPEGImportQuality", 100, "DWord");
        c.Registry.SetValue(Desktop, "Wallpaper", dst, "String");
        FileData.Need(c.Services.Desktop, "desktop").SetWallpaper(dst);
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var img0 = Img0(c);
        c.Registry.SetValue(Wallpapers, "BackgroundType", 0, "DWord");
        c.Registry.SetValue(Desktop, "WallpaperStyle", "10", "String");
        c.Registry.SetValue(Desktop, "TileWallpaper", "0", "String");
        c.Registry.RemoveValue(Desktop, "JPEGImportQuality");
        c.Registry.SetValue(Desktop, "Wallpaper", img0, "String");
        FileData.Need(c.Services.Desktop, "desktop").SetWallpaper(img0);
        var dir = Path.GetDirectoryName(Ours(c))!;
        try { if (Directory.Exists(dir)) Directory.Delete(dir, recursive: true); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { c.Log.Write($"Warning: {dir} kept ({e.Message})"); }
    }
}
