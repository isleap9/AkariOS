using System.Windows;
using System.Windows.Media;

namespace AkariOS.App.Look;

/// <summary>
/// The user's Windows accent (ADR 0008; Set-AkariAccent / Get-AkariAccentColors): the real user's AccentPalette, read
/// through the engine's registry like AppsUseLightTheme (rule 6: the signed-in user's, not the elevated account's).
/// </summary>
public static class Accent
{
    public const string Key = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent";
    public const string Value = "AccentPalette";

    /// <summary>
    /// The accent brushes for a theme (pure): 32 bytes, 8 colours as R, G, B, A: Light3, Light2, Light1, Base, Dark1,
    /// Dark2, Dark3, unused. Dark: Acc = Light2, AccText = Info = Light3, AccT black; Light: Acc = Dark1, AccText = Info
    /// = Dark2, AccT white; AccH / AccP / AccSoft = Acc at 90 / 80 / 10%. Null when the palette is missing or short.
    /// </summary>
    public static IReadOnlyDictionary<string, Color>? Colors(byte[]? palette, string theme)
    {
        if (palette is not { Length: >= 28 }) return null;
        var light = theme == "Light";
        Color At(int i, byte a) => new() { A = a, R = palette[i * 4], G = palette[i * 4 + 1], B = palette[i * 4 + 2] };
        var (acc, text) = light ? (4, 5) : (1, 0);
        var on = light ? new Color { A = 255, R = 255, G = 255, B = 255 } : new Color { A = 255 };
        return new Dictionary<string, Color>
        {
            ["Acc"] = At(acc, 0xFF), ["AccH"] = At(acc, 0xE6), ["AccP"] = At(acc, 0xCC), ["AccSoft"] = At(acc, 0x1A),
            ["AccT"] = on, ["AccText"] = At(text, 0xFF), ["Info"] = At(text, 0xFF),
        };
    }

    /// <summary>Puts the accent brushes into a theme dictionary; false (the theme's default blue stays) without a palette.</summary>
    public static bool Put(ResourceDictionary theme, byte[]? palette, string name)
    {
        if (Colors(palette, name) is not { } colors) return false;
        foreach (var (key, color) in colors)
        {
            var b = new SolidColorBrush(color);
            b.Freeze();
            theme[key] = b;
        }
        return true;
    }
}
