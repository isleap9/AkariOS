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

    /// <summary>The repo's root folder (where AGENTS.md is).</summary>
    internal static string RepoRoot()
    {
        for (var d = new DirectoryInfo(AppContext.BaseDirectory); d != null; d = d.Parent)
            if (File.Exists(Path.Combine(d.FullName, "AGENTS.md"))) return d.FullName;
        throw new DirectoryNotFoundException();
    }

    internal static void OnSta(Action action)
    {
        ExceptionDispatchInfo? error = null;
        // the thread's WPF dispatcher is shut down when the test ends: one left behind on a dead thread can hang the
        // process's exit (WPF's shutdown listeners)
        var t = new Thread(() =>
        {
            try { action(); }
            catch (Exception e) { error = ExceptionDispatchInfo.Capture(e); }
            finally { System.Windows.Threading.Dispatcher.CurrentDispatcher.InvokeShutdown(); }
        });
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

    [Fact]
    public void Icons_are_filled_fluent_paths_in_a_20_box() => OnSta(() =>
    {
        var host = new System.Windows.Controls.Border();
        foreach (var d in AkariXaml.SharedResources("Dark", false)) host.Resources.MergedDictionaries.Add(d);
        host.Resources["Tx"] = Brushes.Red;
        var i = Icons.Make("zap", 20);
        host.Child = i;
        var c = (System.Windows.Controls.Canvas)i.Child;
        var p = (System.Windows.Shapes.Path)c.Children[0];
        Assert.Equal((20d, 20d), (i.Width, c.Width));
        Assert.Same(Brushes.Red, p.Fill);
        Assert.Null(p.Stroke);
        Assert.Same(host.FindResource("Ic.zap"), p.Data);
        Icons.Set(i, "house.Filled");
        Assert.Same(host.FindResource("Ic.house.Filled"), p.Data);
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

    // a green accent: Light3, Light2, Light1, Base, Dark1, Dark2, Dark3, unused (R, G, B, A each); the same as
    // tests/Ui.Tests.ps1's Get-AkariAccentColors cases
    private static readonly byte[] Green =
        [0xA9, 0xF5, 0xA9, 0, 0x6C, 0xCB, 0x5F, 0, 0x3F, 0xB2, 0x3F, 0, 0x10, 0x89, 0x3E, 0, 0x0F, 0x7B, 0x0F, 0, 0x0B, 0x5A, 0x0B, 0, 0x05, 0x3D, 0x05, 0, 0, 0, 0, 0];

    private static string Line(IReadOnlyDictionary<string, Color>? c) =>
        string.Join(" ", new[] { "Acc", "AccH", "AccP", "AccSoft", "AccT", "AccText", "Info" }.Select(k => $"{k}={c![k]}"));

    [Fact]
    public void The_accent_palette_maps_to_the_brushes_as_in_the_PowerShell_app()
    {
        Assert.Equal("Acc=#FF6CCB5F AccH=#E66CCB5F AccP=#CC6CCB5F AccSoft=#1A6CCB5F AccT=#FF000000 AccText=#FFA9F5A9 Info=#FFA9F5A9", Line(Accent.Colors(Green, "Dark")));
        Assert.Equal("Acc=#FF0F7B0F AccH=#E60F7B0F AccP=#CC0F7B0F AccSoft=#1A0F7B0F AccT=#FFFFFFFF AccText=#FF0B5A0B Info=#FF0B5A0B", Line(Accent.Colors(Green, "Light")));
        Assert.Null(Accent.Colors(null, "Dark"));
        Assert.Null(Accent.Colors([1, 2, 3], "Light"));
    }

    [Fact]
    public void The_theme_takes_the_accent_and_follows_its_changes() => OnSta(() =>
    {
        var resources = new ResourceDictionary();
        foreach (var d in AkariXaml.SharedResources("Dark", false)) resources.MergedDictionaries.Add(d);
        byte[]? palette = null;
        var theme = new ThemeService(resources, new SettingsFile(Path.Combine(_dir, "settings.json")), () => 0, false, () => palette);
        theme.Apply("Dark");
        var blue = ((SolidColorBrush)resources["Acc"]).Color;
        Assert.Equal("#FF4CC2FF", blue.ToString());

        palette = Green;
        theme.ApplyAccent();
        Assert.Equal("#FF6CCB5F", ((SolidColorBrush)resources["Acc"]).Color.ToString());
        theme.Apply("Light");
        Assert.Equal("#FF0F7B0F", ((SolidColorBrush)resources["Acc"]).Color.ToString());
        Assert.Equal("#FF0B5A0B", ((SolidColorBrush)resources["AccText"]).Color.ToString());

        // an unreadable palette keeps the theme's default blue
        var broken = new ThemeService(resources, new SettingsFile(Path.Combine(_dir, "settings.json")), () => 0, false, () => throw new IOException());
        broken.Apply("Dark");
        Assert.Equal(blue, ((SolidColorBrush)resources["Acc"]).Color);
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
    public void Logos_are_in_the_exe_and_no_fonts()
    {
        var asm = typeof(Assets).Assembly;
        using var stream = asm.GetManifestResourceStream("AkariOS-Native.g.resources")!;
        using var reader = new ResourceReader(stream);
        var names = reader.Cast<System.Collections.DictionaryEntry>().Select(e => (string)e.Key).ToList();
        foreach (var l in new[] { "akarilogo-dark.png", "akarilogo-light.png", "akarilogo.ico" })
            Assert.Contains($"assets/{l}", names);
        Assert.DoesNotContain(names, n => n.StartsWith("assets/fonts/"));
        Assert.Equal(new Uri(Assets.Base + "AkariLogo-light.png"), Assets.LogoFor("Light"));
    }

    // ADR 0008: Windows' own fonts, from the shared Controls.xaml
    [Fact]
    public void The_fonts_are_segoe_ui_variable_from_the_shared_controls() => OnSta(() =>
    {
        var controls = AkariXaml.SharedResources("Dark", false).Last();
        Assert.Equal(
            ["Segoe UI Variable Display, Segoe UI", "Segoe UI Variable Text, Segoe UI", "Segoe UI Variable Small, Segoe UI", "Cascadia Mono, Consolas"],
            new[] { "FontDisplay", "FontText", "FontSmall", "FontMono" }.Select(k => ((FontFamily)controls[k]).Source));
    });
}
