using System.IO;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Markup;

namespace AkariOS.App;

/// <summary>
/// Loads the XAML shared with the PowerShell app (src/UI), as Get-AkariXaml does (src/UI/Motion.ps1): the Motion
/// tokens are put first into each file's resources, so its styles reach them through StaticResource; with Windows'
/// animation effects off (or AKARI_MOTION=off) every Duration is 0:0:0.
/// </summary>
public static partial class AkariXaml
{
    [GeneratedRegex(@"(?s)<ResourceDictionary\b[^>]*>(.*)</ResourceDictionary>")]
    private static partial Regex MotionBody();

    [GeneratedRegex(@"(<Duration\b[^>]*>)[^<]*(</Duration>)")]
    private static partial Regex DurationValue();

    [GeneratedRegex(@"<ResourceDictionary\b[^>]*[^/]>|<\w+\.Resources>")]
    private static partial Regex ResourcesStart();

    /// <summary>Motion.xaml's entries (the text between its root tags); off = every Duration 0:0:0.</summary>
    public static string MotionEntries(string motionXaml, bool on)
    {
        var m = MotionBody().Match(motionXaml);
        if (!m.Success) throw new InvalidDataException("Motion.xaml has no ResourceDictionary");
        var entries = m.Groups[1].Value;
        return on ? entries : DurationValue().Replace(entries, "${1}0:0:0${2}");
    }

    /// <summary>The XAML with the entries put first into its root ResourceDictionary or first X.Resources.</summary>
    public static string AddMotion(string xaml, string entries)
    {
        var m = ResourcesStart().Match(xaml);
        return m.Success ? xaml.Insert(m.Index + m.Length, entries) : xaml;
    }

    /// <summary>Windows' animation effects; AKARI_MOTION = on / off overrides them.</summary>
    public static bool MotionOn()
    {
        var env = Environment.GetEnvironmentVariable("AKARI_MOTION");
        if (string.Equals(env, "off", StringComparison.OrdinalIgnoreCase)) return false;
        if (string.Equals(env, "on", StringComparison.OrdinalIgnoreCase)) return true;
        try { return SystemParameters.ClientAreaAnimation; } catch (Exception) { return true; }
    }

    /// <summary>A shared file's text, e.g. "Controls.xaml" (embedded from src/UI).</summary>
    public static string Text(string name)
    {
        using var s = typeof(AkariXaml).Assembly.GetManifestResourceStream($"src/UI/{name}")
            ?? throw new FileNotFoundException($"src/UI/{name} is not embedded");
        using var r = new StreamReader(s);
        return r.ReadToEnd();
    }

    /// <summary>A shared file parsed, with the Motion entries in it (Motion.xaml itself: its own, motion on or off).</summary>
    public static object Load(string name, bool motionOn)
    {
        var entries = MotionEntries(Text("Motion.xaml"), motionOn);
        var xaml = name == "Motion.xaml"
            ? MotionBody().Replace(Text(name), m => m.Value.Replace(m.Groups[1].Value, entries))
            : AddMotion(Text(name), entries);
        return XamlReader.Parse(xaml);
    }

    [GeneratedRegex(@"(?s)<Window\.Resources>(.*)</Window\.Resources>")]
    private static partial Regex WindowResources();

    [GeneratedRegex(@"(?s)^<Window\b([^>]*)>")]
    private static partial Regex WindowTag();

    /// <summary>
    /// MainWindow.xaml's window styles (Btn, BtnP, Ghost, Flat, Tab, Chip, Cap, the focus rings, menus, scroll bars,
    /// tooltips...) read out of its Window.Resources as a dictionary of their own, with its namespaces and the Motion
    /// entries: the native window shares them instead of a copy.
    /// </summary>
    public static ResourceDictionary WindowStyles(bool motionOn)
    {
        var xaml = Text("MainWindow.xaml");
        var body = WindowResources().Match(xaml);
        if (!body.Success) throw new InvalidDataException("MainWindow.xaml has no Window.Resources");
        var namespaces = Regex.Matches(WindowTag().Match(xaml.TrimStart()).Groups[1].Value, @"xmlns(:\w+)?=""[^""]*""").Select(m => m.Value);
        var dict = $"<ResourceDictionary {string.Join(' ', namespaces)}>{MotionEntries(Text("Motion.xaml"), motionOn)}{body.Groups[1].Value}</ResourceDictionary>";
        return (ResourceDictionary)XamlReader.Parse(dict);
    }

    /// <summary>The theme's position in <see cref="SharedResources"/> (ThemeService swaps it).</summary>
    public const int ThemeIndex = 1;

    /// <summary>The app's resources in their order: Motion, the theme, Icons, the window styles, Controls.</summary>
    public static IEnumerable<ResourceDictionary> SharedResources(string theme, bool motionOn)
    {
        yield return (ResourceDictionary)Load("Motion.xaml", motionOn);
        yield return (ResourceDictionary)Load($"Theme.{theme}.xaml", motionOn);
        yield return (ResourceDictionary)Load("Icons.xaml", motionOn);
        yield return WindowStyles(motionOn);
        yield return (ResourceDictionary)Load("Controls.xaml", motionOn);
    }
}
