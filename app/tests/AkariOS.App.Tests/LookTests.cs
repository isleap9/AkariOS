using System.IO;
using System.Resources;
using System.Runtime.ExceptionServices;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Media;
using AkariOS.App.Look;

namespace AkariOS.App.Tests;

public sealed class LookTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-look-{Guid.NewGuid():N}");

    public void Dispose()
    {
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    internal static void OnSta(Action action)
    {
        ExceptionDispatchInfo? error = null;
        var t = new Thread(() => { try { action(); } catch (Exception e) { error = ExceptionDispatchInfo.Capture(e); } });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        error?.Throw();
    }

    [Fact]
    public void The_window_styles_come_out_of_the_shared_main_window() => OnSta(() =>
    {
        foreach (var on in new[] { true, false })
        {
            var styles = AkariXaml.WindowStyles(on);
            foreach (var key in new[] { "Ic", "FocusRing", "FocusBox", "Btn", "BtnP", "Ghost", "Cap", "CapX", "Tab", "Chip", "Flat" })
                Assert.True(styles.Contains(key), $"no {key}");
        }
    });

    [Fact]
    public void Every_key_of_the_shared_window_resources_is_there() => OnSta(() =>
    {
        var xaml = AkariXaml.Text("MainWindow.xaml");
        var block = Regex.Match(xaml, @"(?s)<Window\.Resources>(.*)</Window\.Resources>").Groups[1].Value;
        var keys = Regex.Matches(block, @"x:Key=""([A-Za-z][\w.]*)""").Select(m => m.Groups[1].Value).ToList();
        var styles = AkariXaml.WindowStyles(true);
        Assert.NotEmpty(keys);
        Assert.All(keys, k => Assert.True(styles.Contains(k), $"no {k}"));
    });

    [Fact]
    public void The_app_resources_come_in_order_with_the_theme_second() => OnSta(() =>
    {
        var list = AkariXaml.SharedResources("Light", motionOn: false).ToList();
        Assert.Equal(5, list.Count);
        Assert.True(list[0].Contains("Motion.Base"));
        Assert.True(list[AkariXaml.ThemeIndex].Contains("Acc"));
        Assert.True(list[2].Contains("Ic.house"));
        Assert.True(list[3].Contains("BtnP"));
        Assert.True(list[4].Contains("Switch"));
    });

    [Theory]
    [InlineData("Dark", null, "Dark")]
    [InlineData("Light", 0, "Light")]
    [InlineData("System", 1, "Light")]
    [InlineData("System", 0, "Dark")]
    [InlineData("System", null, "Dark")]
    public void Resolves_the_theme(string setting, int? light, string theme) => Assert.Equal(theme, ThemeService.Resolve(setting, light));

    [Fact]
    public void Cycles_system_dark_light() =>
        Assert.Equal(["Dark", "Light", "System"], ThemeService.Settings.Select(ThemeService.Next));

    [Fact]
    public void Applying_swaps_the_theme_and_saves_it() => OnSta(() =>
    {
        var resources = new ResourceDictionary();
        foreach (var d in AkariXaml.SharedResources("Dark", false)) resources.MergedDictionaries.Add(d);
        var settings = new SettingsFile(Path.Combine(_dir, "settings.json"));
        int? light = 1;
        var theme = new ThemeService(resources, settings, () => light, false);
        var changes = 0;
        theme.Changed += () => changes++;
        Assert.Equal("System", theme.Saved());

        var dark = ((SolidColorBrush)resources["Bg"]).Color;
        theme.Apply("System");
        Assert.Equal(("System", "Light"), (theme.Setting, theme.Current));
        Assert.NotEqual(dark, ((SolidColorBrush)resources["Bg"]).Color);
        Assert.Equal(5, resources.MergedDictionaries.Count);

        theme.Apply("Dark", save: true);
        Assert.Equal(dark, ((SolidColorBrush)resources["Bg"]).Color);
        Assert.Equal("Dark", new SettingsFile(settings.Path).Get("Theme"));
        Assert.Equal(2, changes);

        theme.Apply("Purple");
        Assert.Equal("System", theme.Setting);
    });

    [Fact]
    public void Settings_keep_their_other_keys()
    {
        var path = Path.Combine(_dir, "settings.json");
        Directory.CreateDirectory(_dir);
        File.WriteAllText(path, """{ "Theme": "Light", "Other": "kept" }""");
        var s = new SettingsFile(path);
        Assert.Equal("Light", s.Get("Theme"));
        Assert.True(s.Set("Theme", "Dark"));
        Assert.Equal(("Dark", "kept"), (s.Get("Theme"), s.Get("Other")));
        File.WriteAllText(path, "broken");
        Assert.Null(s.Get("Theme"));
        Assert.Equal("System", new ThemeService(new ResourceDictionary(), s, () => null, false).Saved());
    }

    [Theory]
    [InlineData(19045, null, null)]
    [InlineData(22000, 1029, 1)]
    [InlineData(22621, 38, 2)]
    [InlineData(26100, 38, 2)]
    public void Mica_by_build(int build, int? attribute, int? value) =>
        Assert.Equal(attribute is null ? null : (attribute.Value, value!.Value), WindowFrame.Backdrop(build));

    [Theory]
    [InlineData(true, "Dark", "Tint")]
    [InlineData(true, "Light", "Bg")]
    [InlineData(false, "Dark", "Bg")]
    public void The_body_brush(bool mica, string theme, string brush) => Assert.Equal(brush, WindowFrame.BodyBrush(mica, theme));

    [Fact]
    public void Fonts_and_logos_are_in_the_exe()
    {
        var asm = typeof(Assets).Assembly;
        using var stream = asm.GetManifestResourceStream("AkariOS-Native.g.resources")!;
        using var reader = new ResourceReader(stream);
        var names = reader.Cast<System.Collections.DictionaryEntry>().Select(e => (string)e.Key).ToList();
        foreach (var f in new[] { "unbounded-bold.ttf", "unbounded-semibold.ttf", "manrope-medium.ttf", "manrope-semibold.ttf", "manrope-bold.ttf", "jetbrainsmono-medium.ttf" })
            Assert.Contains($"assets/fonts/{f}", names);
        foreach (var l in new[] { "akarilogo-dark.png", "akarilogo-light.png", "akarilogo.ico" })
            Assert.Contains($"assets/{l}", names);
        Assert.Equal(new Uri(Assets.Base + "AkariLogo-light.png"), Assets.LogoFor("Light"));
        Assert.Equal(["FontDisplay", "FontText", "FontMono"], Assets.FontNames.Keys);
    }
}
