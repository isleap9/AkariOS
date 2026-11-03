using System.Drawing;
using System.Drawing.Imaging;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Theme;

/// <summary>src/Tweaks/Customize/Theme/BlackLockScreen.ps1: a black JPEG the size of the main screen (Windows\Black.jpg)
/// set through the lock screen policy. Optimized = the policy names that file and it is there.</summary>
[TweakCode("theme-black-lock-screen")]
public sealed class BlackLockScreen : ITweakCode
{
    private const string Key = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP";

    private static string File(TweakContext c) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "Black.jpg");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var p = PsSemantics.Text(c.Registry.GetValue(Key, "LockScreenImagePath"));
        if (p is null) return TweakState.Default;
        return string.Equals(p, File(c), StringComparison.OrdinalIgnoreCase) && System.IO.File.Exists(p) ? TweakState.Optimized : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var (w, h) = FileData.Need(c.Services.Desktop, "desktop").ScreenSize();
        var file = File(c);
        using (var bmp = new Bitmap(Math.Max(w, 1), Math.Max(h, 1)))
        {
            using (var g = Graphics.FromImage(bmp)) g.Clear(Color.Black);
            bmp.Save(file, ImageFormat.Jpeg);
        }
        c.Registry.SetValue(Key, "LockScreenImagePath", file, "String");
        c.Registry.SetValue(Key, "LockScreenImageStatus", 1, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        c.Registry.RemoveValue(Key, "LockScreenImagePath");
        c.Registry.RemoveValue(Key, "LockScreenImageStatus");
        try { System.IO.File.Delete(File(c)); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }
}
