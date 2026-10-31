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

/// <summary>Home, About and the options menu on the repo's files and a test key; nothing is shown or opened.</summary>
[Collection("Motion")]
public sealed class PagesTests : IDisposable
{
    private readonly string _root = $@"Software\AkariTest\{Guid.NewGuid():N}";
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-pages-{Guid.NewGuid():N}");

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

    private sealed class FakeOpen : IShellOpen
    {
        public List<string> Opened { get; } = [];
        public void Url(string url) => Opened.Add(url);
        public void Folder(string path) => Opened.Add($"folder {path}");
        public void Program(string path) => Opened.Add($"program {Path.GetFileName(path)}");
    }

    private (AppServices S, FakeOpen Open, List<string> Messages, ShellViewModel Vm) Make()
    {
        Motion.Initialize(false);
        var repo = new FolderSourceFiles(RepoRoot());
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
        var vm = new ShellViewModel("1.3.0");
        var open = new FakeOpen();
        var messages = new List<string>();
        var s = new AppServices
        {
            Engine = engine, Shell = vm, Open = open, Log = log, LogFolder = _dir,
            Theme = new ThemeService(resources, new SettingsFile(Path.Combine(_dir, "settings.json")), () => null, false),
            Background = (work, done) => done(work()),
        };
        s.Dialogs = new Dialogs(() => resources, log) { Runner = d => { messages.Add(((TextBlock)d.FindName("DlgText")).Text); return null; } };
        return (s, open, messages, vm);
    }

    private static string RepoRoot()
    {
        for (var d = new DirectoryInfo(AppContext.BaseDirectory); d != null; d = d.Parent)
            if (File.Exists(Path.Combine(d.FullName, "AGENTS.md"))) return d.FullName;
        throw new DirectoryNotFoundException();
    }

    private static IEnumerable<T> All<T>(DependencyObject root) where T : DependencyObject
    {
        if (root is T t) yield return t;
        var children = LogicalTreeHelper.GetChildren(root).OfType<DependencyObject>();
        foreach (var c in children) foreach (var x in All<T>(c)) yield return x;
    }

    private static void Click(ButtonBase b) => b.RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent));

    private static void Click(MenuItem m) => m.RaiseEvent(new RoutedEventArgs(MenuItem.ClickEvent));

    private static Button Button(UIElement page, string text) =>
        All<Button>(page).First(b => b.Content as string == text || b.Tag as string == text);

    [Fact]
    public void Home_has_its_hero_stats_and_cards() => LookTests.OnSta(() =>
    {
        var (s, _, messages, vm) = Make();
        var home = HomePage.Build(s);
        var texts = All<TextBlock>(home).Select(t => t.Text).ToList();
        Assert.Contains("AKARIOS 1.3.0".Replace("1.3.0", AkariInfo.Version), texts);
        Assert.Contains("Windows, tuned for games.", texts);
        Assert.Contains("MORE TOOLS", texts);

        // Tweaks at once, changes applied read (here at once), removable apps a dash until N5
        var tweaks = Catalogue.Tweaks(s.Engine.Loaded.Tweaks, s.Engine.System).Count;
        Assert.True(tweaks > 200, $"{tweaks} Catalogue Tweaks");
        Assert.Contains(tweaks.ToString("N0"), texts);
        Assert.Contains("—", texts);
        Assert.NotNull(s.AppliedCount);

        var grid = All<UniformGrid>(home).Single();
        Assert.Equal(HomePage.Tiles.Select(t => t.Title), grid.Children.OfType<Button>().Select(b => (string)b.Tag));
        Assert.Equal(5, grid.Columns);
        vm.Width = 1100;
        Assert.Equal(3, grid.Columns);

        Click(Button(home, "Optimize"));
        Assert.Equal("Optimize", vm.Page);
        Click(Button(home, "Import / Export settings"));
        Click(All<Button>(home).First(b => b.ToolTip as string == "The full AkariOS setup in one go, with restarts handled for you"));
        Assert.Equal(2, messages.Count);
        Assert.Contains("N3", messages[0]);
        Assert.Contains("One-click isn't in the native app yet: it comes with N7", messages[1]);
        Click(Button(home, "Choose changes"));
        Assert.Equal("Install AkariOS", vm.Page);
    });

    [Fact]
    public void About_reads_the_shared_about_file() => LookTests.OnSta(() =>
    {
        var (s, open, _, vm) = Make();
        var data = AboutData.Read(s.Engine.Files);
        Assert.Equal(["GitHub", "Report a bug", "Discord"], data.Links.Select(l => l.Name));
        Assert.Contains(data.Credits, c => c.Name == "FR33THY Ultimate");
        Assert.StartsWith("MIT License", data.License);

        var about = AboutPage.Build(s);
        Click(Button(about, "GitHub"));
        Click(Button(about, "Open log folder"));
        Click(Button(about, "View license"));
        Click(Button(about, "Open on GitHub"));
        Assert.Equal(["https://github.com/isleap9/AkariOS", $"folder {s.LogFolder}", data.LicenseUrl, AboutData.Releases], open.Opened);
        Assert.Equal(data.Credits.Count, All<System.Windows.Documents.Hyperlink>(about).Count());
        Click(Button(about, "Back"));
        Assert.Equal("Home", vm.Page);
    });

    [Fact]
    public void The_options_menu() => LookTests.OnSta(() =>
    {
        var (s, open, _, vm) = Make();
        var menu = OptionsMenu.Build(s);
        var items = menu.Items.OfType<MenuItem>().ToList();
        Assert.Equal(["Import settings", "Export settings", "System Restore", "Theme: Follow Windows", "GitHub", "Report a bug", "Discord", "Logs", "About"], items.Select(i => (string)i.Header));
        Assert.False(items[0].IsEnabled);
        Assert.Equal("Coming with N3", items[0].ToolTip);

        var theme = items[3];
        Click(theme);
        Assert.Equal(("Dark", "Theme: Dark"), (s.Theme.Setting, (string)theme.Header));
        Click(theme);
        Click(theme);
        Assert.Equal("System", s.Theme.Setting);

        Click(items[2]);
        Click(items[^2]);
        Click(items[^1]);
        Assert.Equal(["program rstrui.exe", $"folder {s.LogFolder}"], open.Opened);
        Assert.Equal("About", vm.Page);
    });

    [Fact]
    public void Every_page_is_built_by_the_factory() => LookTests.OnSta(() =>
    {
        var (s, _, _, _) = Make();
        var pages = PageFactory.For(s);
        Assert.IsType<StackPanel>(pages("Home"));
        Assert.IsType<Grid>(pages("About"));
        Assert.All(ShellLayout.Pages.Keys.Except(["Home", "About"]), p => Assert.Contains(All<TextBlock>(pages(p)), t => t.Text == "Not in the native app yet"));
    });

    [Fact]
    public void Every_icon_home_and_the_menu_name_is_in_Icons_xaml()
    {
        var icons = AkariXaml.Text("Icons.xaml");
        var names = HomePage.Tiles.Select(t => t.Icon).Concat(["zap", "file-input", "file-output", "history", "sun-moon", "github", "bug", "message-circle", "external-link", "folder-open", "info"]);
        Assert.All(names, n => Assert.Contains($"x:Key=\"Ic.{n}\"", icons));
    }

    [Fact]
    public void The_real_opener_cant_be_made_in_a_test() => Assert.Throws<InvalidOperationException>(() => new ShellOpen());
}
