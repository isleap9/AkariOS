using System.IO;
using System.Runtime.ExceptionServices;
using System.Text.RegularExpressions;
using System.Windows;
using AkariOS.App;

namespace AkariOS.App.Tests;

public class AkariXamlTests
{
    // WPF objects need an STA thread; xUnit's are MTA
    private static void OnSta(Action action)
    {
        ExceptionDispatchInfo? error = null;
        var t = new Thread(() => { try { action(); } catch (Exception e) { error = ExceptionDispatchInfo.Capture(e); } });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        error?.Throw();
    }

    [Fact]
    public void Motion_off_writes_every_duration_as_zero()
    {
        var off = AkariXaml.MotionEntries(AkariXaml.Text("Motion.xaml"), on: false);
        var values = Regex.Matches(off, @"<Duration\b[^>]*>([^<]*)</Duration>").Select(m => m.Groups[1].Value).ToList();
        Assert.Equal(4, values.Count);
        Assert.All(values, v => Assert.Equal("0:0:0", v));
    }

    [Fact]
    public void Motion_on_keeps_the_tokens()
    {
        var on = AkariXaml.MotionEntries(AkariXaml.Text("Motion.xaml"), on: true);
        Assert.Contains(">0:0:0.12</Duration>", on);
        Assert.Contains(">0:0:0.2</Duration>", on);
        Assert.Contains(">0:0:0.28</Duration>", on);
        Assert.Contains(">0:0:0.03</Duration>", on);
        Assert.Contains("Motion.Spring", on);
    }

    [Theory]
    [InlineData("<ResourceDictionary a=\"1\"><X/></ResourceDictionary>", "<ResourceDictionary a=\"1\">E<X/></ResourceDictionary>")]
    [InlineData("<Window><Window.Resources><X/></Window.Resources></Window>", "<Window><Window.Resources>E<X/></Window.Resources></Window>")]
    [InlineData("<Window><Grid/></Window>", "<Window><Grid/></Window>")]
    public void Motion_entries_go_first_into_the_resources(string xaml, string expected) =>
        Assert.Equal(expected, AkariXaml.AddMotion(xaml, "E"));

    [Fact]
    public void The_shared_files_parse_with_motion_on_and_off() => OnSta(() =>
    {
        foreach (var on in new[] { true, false })
        foreach (var name in new[] { "Motion.xaml", "Theme.Dark.xaml", "Theme.Light.xaml", "Icons.xaml", "Controls.xaml" })
            Assert.IsType<ResourceDictionary>(AkariXaml.Load(name, on));
    });

    [Fact]
    public void Both_themes_have_the_same_keys() => OnSta(() =>
    {
        static List<string> Keys(string name) =>
            ((ResourceDictionary)AkariXaml.Load(name, true)).Keys.Cast<object>().Select(k => k.ToString()!)
            .Where(k => !k.StartsWith("Motion.", StringComparison.Ordinal)).Order(StringComparer.Ordinal).ToList();
        Assert.Equal(Keys("Theme.Dark.xaml"), Keys("Theme.Light.xaml"));
    });

    [Fact]
    public void The_app_resources_come_in_order() => OnSta(() =>
    {
        var list = AkariXaml.SharedResources("Light", motionOn: false).ToList();
        Assert.Equal(4, list.Count);
        Assert.True(list[0].Contains("Motion.Base"));
        Assert.True(list[1].Contains("Acc"));
        Assert.True(list[3].Contains("Switch"));
    });

    [Fact]
    public void The_window_styles_are_embedded_for_the_key_test() =>
        Assert.Contains("<Window", AkariXaml.Text("MainWindow.xaml"));
}
