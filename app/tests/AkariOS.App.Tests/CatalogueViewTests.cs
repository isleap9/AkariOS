using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.App.Pages;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.App.Tests;

/// <summary>The Catalogue page on the real Tweak files, every registry row redirected to a test key.</summary>
[Collection("Motion")]
public sealed class CatalogueViewTests : IDisposable
{
    private readonly string _root = $@"Software\AkariTest\{Guid.NewGuid():N}";
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-catalogue-{Guid.NewGuid():N}");

    public void Dispose()
    {
        using var hkcu = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64);
        hkcu.DeleteSubKeyTree(_root, throwOnMissingSubKey: false);
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    private sealed class Pc : ISystemInfo
    {
        public int Build => 26100;
        public string Edition => "Professional";
        public Chassis Chassis => Chassis.Desktop;
        public IReadOnlyList<Gpu> Gpus => [];
        public IReadOnlyList<string> GpuDevices => [];
    }

    private sealed class NoExplorer : IExplorer
    {
        public void Restart() { }
    }

    private (AppServices S, CatalogueView Page, List<string> Changes) Make()
    {
        Motion.Initialize(false);
        var repo = new FolderSourceFiles(LookTests.RepoRoot());
        var log = new MemoryLog();
        var engine = new Engine
        {
            Files = repo,
            Registry = new RegistryEngine(new RedirectedRegistryPaths(_root)),
            System = new Pc(),
            Log = log,
            Remembered = new JsonRememberedState(Path.Combine(_dir, "state.json")),
            Explorer = new NoExplorer(),
            Presets = new PresetStore(repo, Path.Combine(_dir, "presets"), Path.Combine(_dir, "lastused.json"), log),
            Codes = new Dictionary<string, ITweakCode>(),
            IsAdmin = () => true,
        };
        var resources = new ResourceDictionary();
        foreach (var d in AkariXaml.SharedResources("Dark", false)) resources.MergedDictionaries.Add(d);
        var s = new AppServices
        {
            Engine = engine, Shell = new ShellViewModel("1"), Open = new NoOpen(), Log = log, LogFolder = _dir,
            Theme = new ThemeService(resources, new SettingsFile(Path.Combine(_dir, "settings.json")), () => null, false),
            Background = (work, done) => done(work()),
        };
        var changes = new List<string>();
        var page = new CatalogueView(s) { Change = (t, mode, value) => changes.Add($"{t.Id} {mode} {value}") };
        return (s, page, changes);
    }

    private sealed class NoOpen : IShellOpen
    {
        public void Url(string url) { }
        public void Folder(string path) { }
        public void Program(string path) { }
    }

    private static IEnumerable<T> All<T>(DependencyObject root) where T : DependencyObject
    {
        if (root is T t) yield return t;
        foreach (var c in LogicalTreeHelper.GetChildren(root).OfType<DependencyObject>())
            foreach (var x in All<T>(c)) yield return x;
    }

    private static List<string> Texts(DependencyObject root) => All<TextBlock>(root).Select(t => t.Text).ToList();

    private static void Apply(AppServices s, string id, TweakMode mode = TweakMode.Apply) => s.Engine.Registry.Invoke(s.Engine.Find(id)!.Registry!, mode, 26100);

    [Fact]
    public void A_category_page_shows_its_tweaks_with_their_states() => LookTests.OnSta(() =>
    {
        var (s, page, _) = Make();
        Apply(s, "gaming-capture-off");
        Apply(s, "disable-game-dvr", TweakMode.Revert);
        var ui = page.Build("Catalogue:Optimize/Gaming", "");
        var list = Catalogue.List(page.Tweaks, "Catalogue:Optimize/Gaming", "");
        Assert.Contains($"{list.Count} tweaks", Texts(ui));
        Assert.Equal(list.Select(t => t.Id), All<Border>(ui).Where(b => b.Tag is string id && list.Any(t => t.Id == id)).Select(b => (string)b.Tag));

        var capture = page.Card(s.Engine.Find("gaming-capture-off")!);
        Assert.Equal((true, "Optimized", true), (((ToggleButton)capture.Control).IsChecked, capture.StateLine.Text, capture.Control.IsEnabled));
        Assert.Contains(All<Border>(capture.Card), b => b.Tag as string == "AkariOS");
        Assert.Contains("gaming-capture-off", Texts(capture.Card));

        var dvr = page.Card(s.Engine.Find("disable-game-dvr")!);
        Assert.Equal((false, "Windows default"), (((ToggleButton)dvr.Control).IsChecked, dvr.StateLine.Text));

        // an Action: its button, no State line; this one has C# still to come: off, and the card says so
        var open = page.Card(s.Engine.Find("gaming-open-game-mode")!);
        Assert.IsType<Button>(open.Control);
        Assert.Equal((Visibility.Collapsed, false), (open.StateLine.Visibility, open.Control.IsEnabled));
        Assert.Contains("Not in the native app yet: the PowerShell app can change it today.", Texts(open.Card));
    });

    [Fact]
    public void A_choice_shows_its_values_and_says_what_was_picked() => LookTests.OnSta(() =>
    {
        var (s, page, changes) = Make();
        s.Engine.Registry.SetValue(@"HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl", "Win32PrioritySeparation", 0x28, "DWord");
        page.Build("Catalogue:Advanced/Tuning", "");
        var c = page.Card(s.Engine.Find("win32-priority-separation")!);
        var box = (ComboBox)c.Control;
        Assert.Equal(["0x26 short, variable, 3:1 (Recommended)", "0x28 short, fixed", "0x18 long, fixed, 3:1"], box.Items.OfType<ComboBoxItem>().Select(i => (string)i.Content));
        Assert.Equal((1, "Custom value"), (box.SelectedIndex, c.StateLine.Text));
        Assert.Contains(All<Viewbox>(c.Card), v => v.ToolTip as string == "Restart required");

        box.SelectedIndex = 2;
        box.SelectedIndex = 0;
        Assert.Equal(["win32-priority-separation Apply 24", "win32-priority-separation Apply "], changes);
        // nothing changed yet: the dropdown shows the value there is
        Assert.Equal(1, box.SelectedIndex);
    });

    [Fact]
    public void A_switch_hands_its_change_on_and_shows_the_state_until_it_runs() => LookTests.OnSta(() =>
    {
        var (s, page, changes) = Make();
        Apply(s, "disable-game-dvr", TweakMode.Revert);
        page.Build("Catalogue:Optimize/Gaming", "");
        var c = page.Card(s.Engine.Find("disable-game-dvr")!);
        var sw = (ToggleButton)c.Control;
        sw.IsChecked = true;
        sw.RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent));
        Assert.Equal(["disable-game-dvr Apply "], changes);
        Assert.False(sw.IsChecked);
    });

    [Fact]
    public void Risk_badges() => LookTests.OnSta(() =>
    {
        var (s, page, _) = Make();
        page.Build("Catalogue:Optimize/Network", "");
        Assert.Contains(All<Border>(page.Card(s.Engine.Find("network-no-throttling")!).Card), b => b.Tag as string == "Caution");
    });

    [Fact]
    public void The_search_heads_each_category_and_says_when_nothing_matches() => LookTests.OnSta(() =>
    {
        var (_, page, _) = Make();
        var ui = page.Build("Home", "dvr");
        var hits = Catalogue.List(page.Tweaks, "", "dvr");
        Assert.NotEmpty(hits);
        var heads = hits.Select(t => $"{Catalogue.HeaderOf(t.Section)} › {t.Category}").Distinct();
        Assert.All(heads, h => Assert.Contains(h, Texts(ui)));
        Assert.Contains("No tweak matches.", Texts(page.Build("Home", "zzzz-nothing")));
    });

    [Fact]
    public void Refresh_reads_the_states_again_and_cards_are_kept() => LookTests.OnSta(() =>
    {
        var (s, page, _) = Make();
        var ui = page.Build("Catalogue:Optimize/Gaming", "");
        var c = page.Card(s.Engine.Find("gaming-capture-off")!);
        Assert.Equal("Windows default", c.StateLine.Text);
        Apply(s, "gaming-capture-off");
        All<Button>(ui).First(b => b.Content as string == "Refresh").RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent));
        Assert.Equal("Optimized", c.StateLine.Text);

        // another page and back: the same card, moved over
        page.Build("Catalogue:Optimize/Power", "");
        var again = page.Build("Catalogue:Optimize/Gaming", "");
        Assert.Contains(c.Card, ((Panel)again).Children.OfType<Border>());
    });

    [Fact]
    public void The_services_page_keeps_its_tweaks_while_its_list_waits() => LookTests.OnSta(() =>
    {
        var (_, page, _) = Make();
        var ui = page.Build("Catalogue:Advanced/Services", "xbox");
        Assert.Contains(Texts(ui), t => t.StartsWith("The list of services on this PC comes with N6", StringComparison.Ordinal));
        Assert.DoesNotContain("No tweak matches.", Texts(ui));
    });

    [Fact]
    public void Searching_from_any_page_looks_through_the_catalogue() => LookTests.OnSta(() =>
    {
        var (s, _, _) = Make();
        var pages = PageFactory.For(s);
        s.Shell.Search = "dvr";
        Assert.Contains(Texts(pages("Home")), t => t.EndsWith("› Gaming", StringComparison.Ordinal));
        Assert.DoesNotContain(Texts(pages("Downloads")), t => t.EndsWith("› Gaming", StringComparison.Ordinal));
    });
}
