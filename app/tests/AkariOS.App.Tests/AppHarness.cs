using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Win32;

namespace AkariOS.App.Tests;

/// <summary>A test's app: the engine on fixture Tweaks (or the real files) with every registry row redirected to a
/// test key, background work run at once (or held), dialogs answered by the test, System Restore, Explorer, the PC's
/// restart and the next boot faked. No WinUI object: view models only.</summary>
internal sealed record AppTest(Engine Engine, CatalogueViewModel Catalogue, ShellState Shell, RestoreRule Restore,
    AppHarness.FakeDialogs Dialogs, AppHarness.FakeBackground Work, AppHarness.FakeExplorer Explorer,
    AppHarness.FakeShutdown Shutdown, AppHarness.FakeRestore Points, AppHarness.FakeBoot Boot, RunStore Runs,
    ServicesListViewModel ServiceList, TasksListViewModel TaskList, FakeServiceManager Services, FakeTaskScheduler Tasks, FakeTrustedInstaller Trusted)
{
    public object? Fix(string name) => Engine.Registry.GetValue(@"HKCU:\Software\AkariFix", name);

    public TweakCardViewModel Card(string id) => Catalogue.Card(Engine.Find(id)!);

    /// <summary>A page as the window opens it.</summary>
    public CataloguePageViewModel Page(string key, string query = "")
    {
        var p = new CataloguePageViewModel(Catalogue, ServiceList, TaskList, new Navigator(Navigated), StartupList);
        p.OnNavigatedTo(new CatalogueQuery(key, query));
        return p;
    }

    public ActivityLog Activity { get; init; } = null!;
    public StartupListViewModel StartupList { get; init; } = null!;
    public FakePackages Packages { get; init; } = null!;
    public FakeDism Dism { get; init; } = null!;
    public FakeWinget Winget { get; init; } = null!;
    public string AssetDir { get; init; } = null!;

    private AppIcons? _icons;
    public AppIcons Icons => _icons ??= new AppIcons(new AssetFiles(AssetDir));

    private RemoveAppsViewModel? _remove;
    public RemoveAppsViewModel Remove => _remove ??= new RemoveAppsViewModel(Engine, Work, Dialogs, Shell, Restore, Catalogue, Stats, Activity, Icons);

    private DownloadsViewModel? _downloads;
    public DownloadsViewModel Downloads => _downloads ??= new DownloadsViewModel(Engine, Work, Dialogs, Shell, Activity, Icons, Remove);

    /// <summary>Install USB's drives (none until the test adds them) and this PC's language (an Italian PC).</summary>
    public AppHarness.FakeDrives Drives { get; } = new();
    public AppHarness.FakeRegion Region { get; } = new();

    private UnattendViewModel? _unattend;
    public UnattendViewModel Unattend => _unattend ??= new UnattendViewModel(Engine, Dialogs, Picker, Open, Shell, Drives, Region);

    /// <summary>The ISO Builder's engine parts (none until AppHarness.Iso / Downloads put the recording fakes in) and its
    /// timers (ticked by hand).</summary>
    public IsoTools IsoTools { get; set; } = new(null, null, null);
    public AppHarness.FakeTimers Timers { get; } = new();

    private IsoBuilderViewModel? _iso;
    public IsoBuilderViewModel Iso => _iso ??= new IsoBuilderViewModel(Engine, IsoTools, Work, Dialogs, Shell, Picker, Open, Timers, Catalogue, Unattend,
        new Navigator(Navigated), Icons) { LogoFolder = Path.Combine(Path.GetDirectoryName(AssetDir)!, "iso-logos") };

    /// <summary>The window's closing question.</summary>
    public ClosingGuard Closing => new(Shell, Downloads, Catalogue, Dialogs);

    /// <summary>The result toasts' titles and lines, newest first.</summary>
    public IReadOnlyList<string> Toasts => Shell.Toasts.Select(x => x.Text.Length > 0 ? $"{x.Title}: {x.Text}" : x.Title).ToList();
    public UpdateService Updates { get; init; } = null!;
    public AppHarness.FakeGitHub GitHub { get; init; } = null!;
    /// <summary>Programs started (the new exe), and the app closed (after an update).</summary>
    public List<string> Started { get; init; } = null!;
    public List<string> Closed { get; init; } = null!;
    public AppHarness.FakeOpen Open { get; } = new();
    public AppHarness.FakePicker Picker { get; } = new();
    public List<string> Navigated { get; } = [];
    public List<string> Accents { get; } = [];

    private sealed class Navigator(List<string> opened) : IShellNavigator
    {
        public void Open(string key) => opened.Add(key);
    }

    /// <summary>Save as preset's name prompt: the queued answers (none = cancelled), the prompts asked.</summary>
    public Queue<string> Names { get; } = new();

    private sealed class Text(Queue<string> names) : ITextDialog
    {
        public Task<string?> AskAsync(string title, string message, string button) => Task.FromResult(names.TryDequeue(out var n) ? n : null);
    }

    /// <summary>Presets handed to One-click's console (the window closed).</summary>
    public List<Preset> OneClicks { get; } = [];

    /// <summary>One-click's browser question: the queued answers by option text (none = cancelled), the options asked.</summary>
    public Queue<string> Picks { get; } = new();
    public List<IReadOnlyList<string>> PickOptions { get; } = [];

    private sealed class Choice(Queue<string> picks, List<IReadOnlyList<string>> asked) : IChoiceDialog
    {
        public Task<int?> PickAsync(string title, string message, IReadOnlyList<string> options, int selected, string button)
        {
            asked.Add(options);
            return Task.FromResult(picks.TryDequeue(out var p) && options.ToList().IndexOf(p) is var i && i >= 0 ? (int?)i : null);
        }
    }

    private HomeStats? _stats;
    public HomeStats Stats => _stats ??= new HomeStats(Engine, Work, Catalogue);

    /// <summary>Optimize's overview as the window opens it.</summary>
    public OptimizeViewModel Optimize()
    {
        var o = new OptimizeViewModel(Catalogue, new Navigator(Navigated));
        o.OnNavigatedTo(null);
        return o;
    }

    private InstallViewModel? _install;

    /// <summary>Install AkariOS: one per test, as the app's.</summary>
    public InstallViewModel Install => _install ??= new InstallViewModel(Engine, Work, Dialogs, new Text(Names), Shell, Restore, Catalogue, Stats, Activity,
        new Navigator(Navigated), Open, Picker, new OneClickHandoff(OneClicks.Add), new Choice(Picks, PickOptions), Icons);

    /// <summary>Home as the window opens it, at a fixed time (Recent activity's "when").</summary>
    public HomeViewModel Home(DateTime? now = null)
    {
        var h = new HomeViewModel(new Navigator(Navigated), Catalogue, new HomeStats(Engine, Work, Catalogue), Updates, Activity, Install, () => now ?? new DateTime(2026, 11, 20, 12, 0, 0));
        h.OnNavigatedTo(null);
        return h;
    }

    /// <summary>Settings; its theme and settings stores are the framework's on a file in the test's folder.</summary>
    public SettingsViewModel Settings(AkariOS.Framework.Services.IThemeService theme, AkariOS.Framework.Services.ISettingsService settings) =>
        new(theme, settings, Open, Picker, Dialogs, Work, Shell, Engine, Updates, new AccentChoice(Accent.Akari, Accents.Add), Install);
}

internal sealed class AppHarness : IDisposable
{
    private readonly string _root = $@"Software\AkariTest\{Guid.NewGuid():N}";

    public string Dir { get; } = Path.Combine(Path.GetTempPath(), $"akari-app-{Guid.NewGuid():N}");

    public void Dispose()
    {
        foreach (var side in _sides) side.Dispose();
        using var hkcu = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64);
        hkcu.DeleteSubKeyTree(_root, throwOnMissingSubKey: false);
        if (Directory.Exists(Dir)) Directory.Delete(Dir, recursive: true);
    }

    private sealed class Pc(Chassis chassis) : ISystemInfo
    {
        public int Build => 26100;
        public string Edition => "Professional";
        public Chassis Chassis => chassis;
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

    internal sealed class FakeBoot : IRunBoot
    {
        public List<string> Steps { get; } = [];
        public void Next(string boot) => Steps.Add($"next {boot}");
        public void SafeBoot(bool on) => Steps.Add($"safeboot {on}");
        public void Restart(int seconds) => Steps.Add($"restart {seconds}");
    }

    internal sealed class FakeRestore : ISystemRestore
    {
        public List<RestorePoint> Points { get; } = [];

        /// <summary>Windows skips every new point (as within 24 hours of the last one).</summary>
        public bool Refuse { get; set; }

        public IReadOnlyList<RestorePoint> List() => Points;

        public void Create(string description)
        {
            if (!Refuse) Points.Add(new(description, DateTime.Now, (uint)Points.Count + 1));
        }
        public void EnableProtection() { }
    }

    /// <summary>Background work: run at once, or kept while Hold is on until the test runs it (a change still running).
    /// Post runs at once.</summary>
    internal sealed class FakeBackground : IBackground
    {
        public Queue<Action> Held { get; } = new();
        public bool Hold { get; set; }

        public void Run(Func<object?> work, Action<object?> done)
        {
            if (Hold) Held.Enqueue(() => done(work()));
            else done(work());
        }

        /// <summary>Runs the held work (and any it starts), with Hold off.</summary>
        public void Release()
        {
            Hold = false;
            while (Held.TryDequeue(out var run)) run();
        }

        public void Post(Action action) => action();
    }

    /// <summary>The dialogs: each message asked is recorded; the answer is the button text the test queued (none =
    /// Esc / cancel).</summary>
    internal sealed class FakeDialogs : IDialogService
    {
        public List<string> Asked { get; } = [];
        public Queue<string> Answers { get; } = new();

        private string? Answer(string message)
        {
            Asked.Add(message);
            return Answers.TryDequeue(out var a) ? a : null;
        }

        public Task<ContentDialogResult> ShowAsync(string title, string content, string primaryText = "OK", string? secondaryText = null, string? cancelText = null)
        {
            var a = Answer(content);
            return Task.FromResult(a == primaryText ? ContentDialogResult.Primary : a is not null && a == secondaryText ? ContentDialogResult.Secondary : ContentDialogResult.None);
        }

        public Task<bool> ConfirmAsync(string title, string message, string confirmText = "Confirm", string? cancelText = "Cancel") =>
            Task.FromResult(Answer(message) == confirmText);

        public Task ShowInfoAsync(string title, string message) { Asked.Add(message); return Task.CompletedTask; }
        public Task ShowErrorAsync(string title, string message) { Asked.Add(message); return Task.CompletedTask; }
        public Task<ContentDialogResult> ShowDialogAsync(ContentDialog dialog) => throw new NotSupportedException("no WinUI dialog in tests");

        public Task<ContentDialogResult> ShowDialogAsync<T>(object viewModel, string title, string primaryText, string? secondaryText = null, string? cancelText = null)
            where T : Microsoft.UI.Xaml.UIElement, new() => throw new NotSupportedException("no WinUI dialog in tests");
    }

    /// <summary>files: fixture ones, else the repo's src/ (the real Tweaks and lists).</summary>
    public AppTest Make(ISourceFiles? files = null, bool safeMode = false, Chassis chassis = Chassis.Desktop)
    {
        files ??= new FolderSourceFiles(Core.Tests.Repo.Root);
        var (services, tasks) = (new FakeServiceManager(), new FakeTaskScheduler());
        var (packages, dism, winget) = (new FakePackages(), new FakeDism(), new FakeWinget());
        var trusted = new FakeTrustedInstaller(tasks);
        Directory.CreateDirectory(Dir);
        var log = new MemoryLog();
        var apps = new Core.Apps.AppPackages(packages, dism, log);
        var (explorer, shutdown, points, boot) = (new FakeExplorer(), new FakeShutdown(), new FakeRestore(), new FakeBoot());
        var runs = new RunStore(Path.Combine(Dir, "run.json"), () => boot.Steps.Add("clear"));
        var engine = new Engine
        {
            RunStore = runs,
            RunBoot = boot,
            Services = new TweakServices
            {
                Services = services, Tasks = tasks, Trusted = trusted, Windows = @"C:\Windows", Apps = apps,
                Winget = new Core.Apps.Winget(winget, packages, new NoDownloads(), apps, null, log, Dir, @"C:\Windows", _ => { }),
            },
            Files = files,
            Registry = new RegistryEngine(new RedirectedRegistryPaths(_root)),
            System = new Pc(chassis),
            Log = log,
            Remembered = new JsonRememberedState(Path.Combine(Dir, "state.json")),
            Explorer = explorer,
            Presets = new PresetStore(files, Path.Combine(Dir, "presets"), Path.Combine(Dir, "lastused.json"), log),
            Codes = new Dictionary<string, ITweakCode>(),
            IsAdmin = () => true,
            SystemRestore = points,
            Shutdown = shutdown,
            InSafeMode = () => safeMode,
        };
        Assert.Equal("", string.Join(" / ", engine.Loaded.Problems.Select(p => $"{p.File}: {p.Message}")));
        var (dialogs, work, shell) = (new FakeDialogs(), new FakeBackground(), new ShellState());
        var restore = new RestoreRule(engine, dialogs);
        var activity = new ActivityLog(Path.Combine(Dir, "activity.json"), log);
        var catalogue = new CatalogueViewModel(engine, work, dialogs, shell, restore, activity);
        var (github, run) = (new FakeGitHub(), new FakeExe());
        var exe = Path.Combine(Dir, "AkariOS-Native.exe");
        File.WriteAllBytes(exe, [1]);
        var closed = new List<string>();
        var updates = new UpdateService(github, new Core.Update.Updater(new FakeHttp(), run, log, _ => "1.4.0"), exe, developerBuild: false, () => false, "1.3.0",
            work, dialogs, shell, catalogue, log, () => closed.Add("closed"));
        return new AppTest(engine, catalogue, shell, restore, dialogs, work, explorer, shutdown, points, boot, runs,
            new ServicesListViewModel(engine, work, dialogs, catalogue), new TasksListViewModel(engine, work, catalogue), services, tasks, trusted)
        {
            StartupList = new StartupListViewModel(engine, work, dialogs, catalogue, activity),
            Activity = activity, Updates = updates, GitHub = github, Started = run.Started, Closed = closed,
            Packages = packages, Dism = dism, Winget = winget, AssetDir = Path.Combine(Dir, "assets"),
        };
    }

    /// <summary>GitHub's latest release: v1.4.0 with AkariOS-Native.exe (NewExe's digest), or Status's error.</summary>
    internal sealed class FakeGitHub : Core.Update.IGitHub
    {
        public static readonly byte[] NewExe = [7, 8, 9];
        public int Status { get; set; } = 200;
        public int Calls { get; private set; }

        public Core.Update.GitHubAnswer Get(string path)
        {
            Calls++;
            if (Status != 200) return new(Status, null, null);
            var body = System.Text.Json.JsonSerializer.Serialize(new
            {
                tag_name = "v1.4.0", body = "## New\n- **Faster** start", html_url = "https://x/release",
                assets = new[] { new { name = "AkariOS-Native.exe", browser_download_url = "https://x/exe", digest = "sha256:" + Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(NewExe)) } },
            });
            return new(200, System.Text.Json.JsonDocument.Parse(body).RootElement.Clone(), null);
        }
    }

    private sealed class FakeHttp : Core.Update.IHttp
    {
        public void Download(string url, string file) => File.WriteAllBytes(file, FakeGitHub.NewExe);
    }

    /// <summary>Programs started (the new exe after an update): recorded, never run.</summary>
    internal sealed class FakeExe : IExe
    {
        public List<string> Started { get; } = [];
        public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true) { Started.Add(path); return new(0, ""); }
    }

    /// <summary>The file dialogs: the path they "pick" (null = cancelled), the names suggested.</summary>
    internal sealed class FakePicker : IFilePicker
    {
        public string? SavePath { get; set; }
        public string? OpenPath { get; set; }
        public string? XmlPath { get; set; }
        public string? FolderPath { get; set; }
        public string? IsoPath { get; set; }
        public List<string> Suggested { get; } = [];
        public Task<string?> SaveJsonAsync(string suggestedName) { Suggested.Add(suggestedName); return Task.FromResult(SavePath); }
        public Task<string?> OpenJsonAsync() => Task.FromResult(OpenPath);
        public Task<string?> OpenXmlAsync() => Task.FromResult(XmlPath);
        public Task<string?> FolderAsync() => Task.FromResult(FolderPath);
        public Task<string?> OpenIsoAsync() => Task.FromResult(IsoPath);
        public string? ZipPath { get; set; }
        public Task<string?> SaveZipAsync(string suggestedName) { Suggested.Add(suggestedName); return Task.FromResult(ZipPath); }
    }

    /// <summary>The timers started (the Massgrave watch): Tick calls every one still running.</summary>
    internal sealed class FakeTimers : ITimers
    {
        private readonly List<Timer> _all = [];

        public sealed class Timer(TimeSpan interval, Action tick) : IDisposable
        {
            public TimeSpan Interval { get; } = interval;
            public Action OnTick { get; } = tick;
            public bool Stopped { get; private set; }
            public void Dispose() => Stopped = true;
        }

        public IReadOnlyList<Timer> All => _all;

        public IDisposable Every(TimeSpan interval, Action tick)
        {
            var t = new Timer(interval, tick);
            _all.Add(t);
            return t;
        }

        public void Tick()
        {
            foreach (var t in _all.Where(t => !t.Stopped).ToList()) t.OnTick();
        }
    }

    private readonly List<IDisposable> _sides = [];

    /// <summary>The ISO Builder's engine on the Core tests' recording fakes (IsoShared.cs): a case's ISO drive,
    /// output folder and test key, kept until the harness is disposed. The ISO file is the side's Win11.iso.</summary>
    public (Core.Tests.IsoBuildOracleTests.Side Side, Core.Tests.IsoFakes Fakes) Iso(AppTest t, Dictionary<string, object>? c = null, string? akariExe = null)
    {
        c ??= Core.Tests.IsoBuildOracleTests.Case();
        var side = new Core.Tests.IsoBuildOracleTests.Side(c);
        _sides.Add(side);
        File.WriteAllText(Path.Combine(side.Root, "Win11.iso"), "iso");
        var f = new Core.Tests.IsoFakes(side, c);
        t.IsoTools = t.IsoTools with { Build = new Core.Iso.IsoBuild(f.Parts with { Log = t.Engine.Log }), AkariExe = akariExe };
        return (side, f);
    }

    /// <summary>The ISO Builder's downloads on the Core tests' recording fakes: a case's answers, its own folders.</summary>
    public (Core.Tests.IsoDownloadOracleTests.Side Side, Core.Tests.DownloadFakes Fakes) Downloads(AppTest t, Dictionary<string, object> c)
    {
        var side = new Core.Tests.IsoDownloadOracleTests.Side(c);
        _sides.Add(side);
        var f = new Core.Tests.DownloadFakes(side.Root, c);
        t.IsoTools = t.IsoTools with { Download = new Core.Iso.IsoDownload(f.Parts with { Log = t.Engine.Log }) };
        return (side, f);
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

    /// <summary>What the app opened outside itself: links, folders, programs (recorded only).</summary>
    internal sealed class FakeOpen : IShellOpen
    {
        public List<string> Opened { get; } = [];
        public void Url(string url) => Opened.Add(url);
        public void Folder(string path) => Opened.Add(path);
        public void Program(string path) => Opened.Add(path);
    }

    /// <summary>Fixture Tweaks in one Category (Optimize › Test): HKCU rows under Software\AkariFix.</summary>
    public static MemorySourceFiles Fixtures() => new MemorySourceFiles()
        .Add("src/UI/About.psd1", File.ReadAllText(Path.Combine(Core.Tests.Repo.Src, "UI", "About.psd1")))
        .Add("src/Tweaks/Optimize/Test/Plain.ps1", Toggle("fix-plain", "Plain", "Explorer = $true"))
        .Add("src/Tweaks/Optimize/Test/Asking.ps1", Toggle("fix-asking", "Asking", "Confirm = 'Really change it?'"))
        .Add("src/Tweaks/Optimize/Test/Safe.ps1", Toggle("fix-safe", "Safe", "SafeMode = $true"))
        .Add("src/Tweaks/Optimize/Test/Reboots.ps1", Toggle("fix-reboots", "Reboots", "Reboot = $true"))
        .Add("src/Tweaks/Customize/Look/Dark.ps1", Toggle("fix-dark", "Dark", "Risk = 'Caution'", "Customize", "Look"))
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
            """)
        .Add("src/Tweaks/Optimize/Other/Run.ps1", """
            # Action: a fixture with no Windows default
            @{
                Id = 'fix-run'; Name = 'Run it'; Section = 'Optimize'; Category = 'Other'; Kind = 'Action'; Risk = 'Safe'; Description = 'An action.'
                Button = 'Open'
                Apply = { Start-Thing }
            }
            """);

    private static string Toggle(string id, string name, string extra, string section = "Optimize", string category = "Test")
    {
        var risk = extra.Contains("Risk", StringComparison.Ordinal) ? "" : "Risk = 'Safe';";
        return $$"""
            @{
                Id = '{{id}}'; Name = '{{name}}'; Section = '{{section}}'; Category = '{{category}}'; {{risk}} Description = 'A fixture.'
                {{extra}}
                Registry = @( @{ Path = 'HKCU:\Software\AkariFix'; Name = '{{name}}'; Type = 'DWord'; Value = 1; Default = $null } )
            }
            """;
    }
}
