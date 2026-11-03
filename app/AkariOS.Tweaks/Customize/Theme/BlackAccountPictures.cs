using System.Drawing;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Theme;

/// <summary>src/Tweaks/Customize/Theme/BlackAccountPictures.ps1: the default account pictures (ProgramData\Microsoft\User
/// Account Pictures, .png and .bmp) painted black at their own size and format, the originals kept first in
/// ProgramData\User Account Pictures for Revert. Optimized = user.png differs from the kept original.</summary>
[TweakCode("theme-black-account-pictures")]
public sealed class BlackAccountPictures : ITweakCode
{
    private static string Data(TweakContext c) => TweakServices.Folder(c.Services.ProgramData, "ProgramData");
    private static string Pictures(TweakContext c) => Path.Combine(Data(c), @"Microsoft\User Account Pictures");
    private static string Kept(TweakContext c) => Path.Combine(Data(c), "User Account Pictures");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var pic = Path.Combine(Pictures(c), "user.png");
        var bak = Path.Combine(Kept(c), "user.png");
        if (!File.Exists(bak)) return TweakState.Default;
        if (!File.Exists(pic)) return TweakState.Unknown;
        return File.ReadAllBytes(pic).AsSpan().SequenceEqual(File.ReadAllBytes(bak)) ? TweakState.Default : TweakState.Optimized;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var dir = Pictures(c);
        if (!Directory.Exists(Kept(c))) Copy(dir, Kept(c));
        foreach (var f in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories)
                     .Where(f => Path.GetExtension(f).ToLowerInvariant() is ".png" or ".bmp").ToList())
        {
            int w, h;
            System.Drawing.Imaging.ImageFormat format;
            using (var b = new Bitmap(f)) (w, h, format) = (b.Width, b.Height, b.RawFormat);
            using var n = new Bitmap(w, h);
            using (var g = Graphics.FromImage(n)) g.Clear(Color.Black);
            n.Save(f, format);
        }
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        if (Directory.Exists(Kept(c))) Copy(Kept(c), Pictures(c));
    }

    // Copy-Item -Recurse -Force: the folder's files and subfolders, replacing what is there
    private static void Copy(string from, string to)
    {
        Directory.CreateDirectory(to);
        foreach (var f in Directory.EnumerateFiles(from, "*", SearchOption.AllDirectories))
        {
            var dst = Path.Combine(to, Path.GetRelativePath(from, f));
            Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
            File.Copy(f, dst, overwrite: true);
        }
    }
}
