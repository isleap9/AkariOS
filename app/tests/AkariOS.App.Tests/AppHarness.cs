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
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.App.Tests;

/// <summary>A test's app: the services on the real Tweak files (or fixture ones), every registry row redirected to
/// a test key, background work run at once, dialogs answered by the test (in order; none = Esc; "text|button" types
/// the text first), System Restore, Explorer and the PC's restart faked.</summary>
internal sealed record AppTest(AppServices S, CatalogueView Page, InstallPage Install, StepFooter Footer, List<string> Asked,
    Queue<string> Answers, AppHarness.FakeExplorer Explorer, AppHarness.FakeShutdown Shutdown, AppHarness.FakeRestore Restore, StackPanel Bars,
    AppHarness.FakePicker Picker)
{
    /// <summary>The PC's Store packages and features (the Apps step's reads).</summary>
    public FakePackages Packages { get; init; } = new();
    public FakeDism Dism { get; init; } = new();

    /// <summary>The PC's services and scheduled tasks (the Services and Scheduled tasks pages), TrustedInstaller.</summary>
    public FakeServiceManager Services { get; init; } = new();
    public FakeTaskScheduler Tasks { get; init; } = new();
    public FakeTrustedInstaller Trusted { get; init; } = null!;

    /// <summary>The next boot and the PC's restart of a Run in phases (recorded), and its run.json.</summary>
    public AppHarness.FakeBoot Boot { get; init; } = null!;
    public Core.Runs.RunStore Runs { get; init; } = null!;

    /// <summary>The Unattend Generator's drives and this PC's language settings; the folders the app opened.</summary>
    public AppHarness.FakeDrives Drives { get; init; } = null!;
    public AppHarness.FakeRegion Region { get; init; } = null!;
    public List<string> Opened { get; init; } = null!;
}

/// <summary>Makes <see cref="AppTest"/>s; one per test class instance, cleaning its test key and folder after.</summary>
internal sealed class AppHarness : IDisposable
{
    private readonly string _root = $@"Software\AkariTest\{Guid.NewGuid():N}";

    public string Dir { get; } = Path.Combine(Path.GetTempPath(), $"akari-app-{Guid.NewGuid():N}");

    public void Dispose()
    {
        using var hkcu = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64);
        hkcu.DeleteSubKeyTree(_root, throwOnMissingSubKey: false);
        if (Directory.Exists(Dir)) Directory.Delete(Dir, recursive: true);
    }

    private sealed class Pc : ISystemInfo
    {
        public int Build => 26100;
        public string Edition => "Professional";
        public Chassis Chassis => Chassis.Desktop;
        public IReadOnlyList<Gpu> Gpus => [];
        public IReadOnlyList<string> GpuDevices => [];
    }

    internal sealed class FakeExplorer : IExplorer
    {
        public int Restarts { get; private set; }
        public void Restart() => Restarts++;
    }

    internal sealed class FakeShutdown : IShutdown
    {
        public int Restarts { get; private set; }
        public void Restart() => Restarts++;
    }

    internal sealed class FakeBoot : Core.Runs.IRunBoot
    {
        public List<string> Steps { get; } = [];
        public void Next(string boot) => Steps.Add($"next {boot}");
        public void SafeBoot(bool on) => Steps.Add($"safeboot {on}");
        public void Restart(int seconds) => Steps.Add($"restart {seconds}");
    }

    internal sealed class FakeRestore : ISystemRestore
    {
        public List<RestorePoint> Points { get; } = [];
        public bool Refuse { get; set; }
        public IReadOnlyList<RestorePoint> List() => Points;
        public void Create(string description)
        {
            if (Refuse) throw new InvalidOperationException("System Protection is off.");
            Points.Add(new(description, DateTime.Now, (uint)Points.Count + 1));
        }
        public void EnableProtection() { }
    }

    /// <summary>The file dialogs: the paths they "pick" (null = cancelled), and the names Save suggested.</summary>
    internal sealed class FakePicker : IFilePicker
    {
        public string? SavePath { get; set; }
        public string? OpenPath { get; set; }
        public List<string> Suggested { get; } = [];
        public string? Save(string suggested) { Suggested.Add(suggested); return SavePath; }
        public string? Open() => OpenPath;
        public string? FolderPath { get; set; }
        public string? XmlPath { get; set; }
        public string? Folder(string description) => FolderPath;
        public string? OpenXml() => XmlPath;
    }

    /// <summary>Records the folders opened; links and programs are not.</summary>
    private sealed class NoOpen(List<string> opened) : IShellOpen
    {
        public void Url(string url) { }
        public void Folder(string path) => opened.Add(path);
        public void Program(string path) { }
    }

    /// <summary>The drives a setup file can go on (the test's temp folders as roots); Fail = the read fails.</summary>
    internal sealed class FakeDrives : Core.Unattend.ISetupDrives
    {
        public List<Core.Unattend.SetupDrive> Drives { get; } = [];
        public bool Fail { get; set; }
        public IReadOnlyList<Core.Unattend.SetupDrive> All() => Fail ? throw new IOException("no drives") : [.. Drives];
    }

    /// <summary>This PC's language settings (an Italian PC unless the test says otherwise).</summary>
    internal sealed class FakeRegion : Core.Unattend.IPcRegion
    {
        public Core.Unattend.PcRegion Pc { get; set; } = new("it-IT", "it-IT", "00000410", "118", "W. Europe Standard Time");
        public Core.Unattend.PcRegion Read() => Pc;
    }

    public AppTest Make(ISourceFiles? files = null, bool safeMode = false)
    {
        Motion.Initialize(false);
        files ??= new FolderSourceFiles(LookTests.RepoRoot());
        var log = new MemoryLog();
        var (explorer, shutdown, restore) = (new FakeExplorer(), new FakeShutdown(), new FakeRestore());
        var (packages, dism) = (new FakePackages(), new FakeDism());
        var (services, tasks) = (new FakeServiceManager(), new FakeTaskScheduler());
        var trusted = new FakeTrustedInstaller(tasks);
        var boot = new FakeBoot();
        var runs = new Core.Runs.RunStore(Path.Combine(Dir, "run.json"), () => boot.Steps.Add("clear"));
        var engine = new Engine
        {
            RunStore = runs,
            RunBoot = boot,
            Services = new TweakServices
            {
                Apps = new Core.Apps.AppPackages(packages, dism, log), Services = services, Tasks = tasks, Trusted = trusted, Windows = @"C:\Windows",
            },
            Files = files,
            Registry = new RegistryEngine(new RedirectedRegistryPaths(_root)),
            System = new Pc(),
            Log = log,
            Remembered = new JsonRememberedState(Path.Combine(Dir, "state.json")),
            Explorer = explorer,
            Presets = new PresetStore(files, Path.Combine(Dir, "presets"), Path.Combine(Dir, "lastused.json"), log),
            Codes = new Dictionary<string, ITweakCode>(),
            IsAdmin = () => true,
            SystemRestore = restore,
            Shutdown = shutdown,
            InSafeMode = () => safeMode,
        };
        var resources = new ResourceDictionary();
        foreach (var d in AkariXaml.SharedResources("Dark", false)) resources.MergedDictionaries.Add(d);
        var asked = new List<string>();
        var answers = new Queue<string>();
        var bars = new StackPanel();
        var picker = new FakePicker();
        var (drives, region, opened) = (new FakeDrives(), new FakeRegion(), new List<string>());
        var s = new AppServices
        {
            Engine = engine, Shell = new ShellViewModel("1"), Open = new NoOpen(opened), Log = log, LogFolder = Dir,
            Drives = drives, Region = region,
            Theme = new ThemeService(resources, new SettingsFile(Path.Combine(Dir, "settings.json")), () => null, false),
            Background = (work, done) => done(work()),
            Bars = bars,
            Picker = picker,
            Post = a => a(),
        };
        s.Dialogs = new Dialogs(() => resources, log)
        {
            Runner = d =>
            {
                asked.Add(((TextBlock)d.FindName("DlgText")).Text);
                // the dialog is never shown: closed once answered
                try
                {
                    if (!answers.TryDequeue(out var a)) return null;
                    var bar = a.IndexOf('|');
                    if (bar < 0) return a;
                    ((TextBox)d.FindName("DlgInput")).Text = a[..bar];
                    return a[(bar + 1)..];
                }
                finally { d.Close(); }
            },
        };
        var footer = new StepFooter(new Border(), new Button(), new StackPanel(), new Button());
        s.Footer = footer;
        s.Catalogue = new CatalogueView(s);
        s.Install = new InstallPage(s);
        s.Install.Attach(footer);
        Assert.Equal("", string.Join(" / ", engine.Loaded.Problems.Select(p => $"{p.File}: {p.Message}")));
        return new AppTest(s, s.Catalogue, s.Install, footer, asked, answers, explorer, shutdown, restore, bars, picker) { Packages = packages, Dism = dism, Services = services, Tasks = tasks, Trusted = trusted, Boot = boot, Runs = runs, Drives = drives, Region = region, Opened = opened };
    }

    /// <summary>Fixture Tweaks in one Category (Optimize › Test): HKCU rows under Software\AkariFix.</summary>
    public static MemorySourceFiles Fixtures() => new MemorySourceFiles()
        .Add("src/Tweaks/Optimize/Test/Plain.ps1", Toggle("fix-plain", "Plain", "Explorer = $true"))
        .Add("src/Tweaks/Optimize/Test/Asking.ps1", Toggle("fix-asking", "Asking", "Confirm = 'Really change it?'"))
        .Add("src/Tweaks/Optimize/Test/Safe.ps1", Toggle("fix-safe", "Safe", "SafeMode = $true"))
        .Add("src/Tweaks/Optimize/Test/Reboots.ps1", Toggle("fix-reboots", "Reboots", "Reboot = $true"))
        .Add("src/Tweaks/Optimize/Test/Restarts.ps1", Toggle("fix-restarts", "Restarts", "Restarts = $true"))
        .Add("src/Tweaks/Customize/Hidden/Hidden.ps1", Toggle("fix-hidden", "Hidden", "Guided = $false", "Customize", "Hidden"))
        .Add("src/Tweaks/Optimize/Test/Pick.ps1", """
            @{
                Id = 'fix-pick'; Name = 'Pick'; Section = 'Optimize'; Category = 'Test'; Kind = 'Choice'; Risk = 'Safe'; Description = 'A fixture.'
                Registry = @{ Path = 'HKCU:\Software\AkariFix'; Name = 'Pick'; Type = 'DWord' }
                Choices = @(
                    @{ Value = 1; Label = 'One' }
                    @{ Value = 2; Label = 'Two' }
                    @{ Value = 3; Label = 'Three'; Risk = 'Advanced' }
                )
                Recommended = 1
                Default = 2
            }
            """);

    private static string Toggle(string id, string name, string extra, string section = "Optimize", string category = "Test") => $$"""
        @{
            Id = '{{id}}'; Name = '{{name}}'; Section = '{{section}}'; Category = '{{category}}'; Risk = 'Safe'; Description = 'A fixture.'
            {{extra}}
            Registry = @( @{ Path = 'HKCU:\Software\AkariFix'; Name = '{{name}}'; Type = 'DWord'; Value = 1; Default = $null } )
        }
        """;

    public static IEnumerable<T> All<T>(DependencyObject root) where T : DependencyObject
    {
        if (root is T t) yield return t;
        foreach (var c in LogicalTreeHelper.GetChildren(root).OfType<DependencyObject>())
            foreach (var x in All<T>(c)) yield return x;
    }

    public static List<string> Texts(DependencyObject root) => All<TextBlock>(root).Select(t => t.Text).ToList();

    public static void Click(ButtonBase b) => b.RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent));

    public static object? Fix(AppServices s, string name) => s.Engine.Registry.GetValue(@"HKCU:\Software\AkariFix", name);

    public static void Apply(AppServices s, string id, TweakMode mode = TweakMode.Apply) => s.Engine.Registry.Invoke(s.Engine.Find(id)!.Registry!, mode, 26100);
}
