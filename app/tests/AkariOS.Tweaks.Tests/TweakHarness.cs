using AkariOS.Core;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests
{
    /// <summary>The repo's root (for the shared Oracle runner).</summary>
    internal static class Repo
    {
        public static string Root { get; } = Find();

        public static string Src => Path.Combine(Root, "src");

        private static string Find()
        {
            for (var d = new DirectoryInfo(AppContext.BaseDirectory); d != null; d = d.Parent)
                if (File.Exists(Path.Combine(d.FullName, "AGENTS.md")) && Directory.Exists(Path.Combine(d.FullName, "src"))) return d.FullName;
            throw new DirectoryNotFoundException("The repo root was not found");
        }
    }
}

namespace AkariOS.Tweaks.Tests
{
    using AkariOS.Core.Tests;

    /// <summary>
    /// An engine on the real src/Tweaks files and this assembly's classes, every registry row on a test key, every
    /// other part of the system faked (rule 12). One per test; disposing deletes the key and the temp folder.
    /// </summary>
    internal sealed class TweakHarness : IDisposable
    {
        private static readonly Lazy<LoadResult> Loaded = new(() => new Loader(new FolderSourceFiles(Repo.Root), TweaksAssembly.Codes).Load());

        private readonly TestKey _key = new();

        public string Dir { get; } = Path.Combine(Path.GetTempPath(), $"akari-tweaks-{Guid.NewGuid():N}");
        public FakeHosts Hosts { get; } = new();
        public FakeBindings Bindings { get; } = new();
        public FakeLauncher Launcher { get; } = new();
        public FakeServices Services { get; } = new();
        public FakeTasks Tasks { get; } = new();
        public FakeExe Exe { get; } = new();
        public FakeMemory Memory { get; } = new();
        public FakeBitLocker BitLocker { get; } = new();
        public FakePowerCfg PowerCfg { get; } = new();
        public FakeProcesses Processes { get; } = new();
        public CountingExplorer Explorer { get; } = new();
        public FakeShortcuts Shortcuts { get; } = new();
        public FakeDesktop Desktop { get; } = new();
        public FakeTrusted Trusted { get; } = new();
        public FakeBcd Bcd { get; } = new();
        public FakeW32tm W32tm { get; } = new();
        public FakeAppSettings Apps { get; } = new();
        public FakeDownloads Downloads { get; } = new();
        public FakeHttp Http { get; } = new();
        public FakeRestore Restore { get; } = new();
        public FakeHardware Hardware { get; } = new();
        public FakeClipboard Clipboard { get; } = new();
        public FakeWevtutil Wevtutil { get; } = new();
        public FakeCleanMgr CleanMgr { get; } = new();
        public FakeDriverStore Drivers { get; } = new();
        public FakeShutdown Shutdown { get; } = new();
        public FakeWinget Winget { get; } = new();
        public FakeAppx Appx { get; } = new();
        public JsonRememberedState Remembered { get; }
        public FakePc Pc { get; } = new();
        public DateTime Now { get; set; } = new(2026, 11, 3, 12, 0, 0, DateTimeKind.Utc);
        public Engine Engine { get; }
        public MemoryLog Log { get; } = new();

        public TweakHarness()
        {
            Directory.CreateDirectory(Dir);
            var files = new FolderSourceFiles(Repo.Root);
            Remembered = new JsonRememberedState(Path.Combine(Dir, "state.json"));
            var apps = new Core.Apps.AppPackages(Appx, Drivers, Log);
            Engine = new Engine
            {
                Files = files,
                Registry = new RegistryEngine(_key.Paths, Trusted),
                System = Pc,
                Log = Log,
                Remembered = Remembered,
                Explorer = new NoExplorer(),
                Presets = new PresetStore(files, Path.Combine(Dir, "presets"), Path.Combine(Dir, "lastused.json"), Log),
                Codes = TweaksAssembly.Codes,
                IsAdmin = () => true,
                InSafeMode = () => false,
                Services = new TweakServices
                {
                    Hosts = Hosts, Bindings = Bindings, Launcher = Launcher, Services = Services, Tasks = Tasks, Exe = Exe,
                    Memory = Memory, BitLocker = BitLocker, PowerCfg = PowerCfg, Trusted = Trusted,
                    Processes = Processes, Explorer = Explorer, Shortcuts = Shortcuts, Desktop = Desktop, BcdEdit = Bcd, W32tm = W32tm, AppSettings = Apps,
                    Downloads = Downloads, Remembered = Remembered, SystemRestore = Restore,
                    ProgramData = Folder("ProgramData"), Windows = Folder("Windows"), SystemDrive = Folder("C"), FilesFolder = Folder("Files"),
                    ProgramFiles = Folder("Program Files"), ProgramFilesX86 = Folder("Program Files (x86)"), Public = Folder("Public"),
                    LocalAppData = Folder("LocalAppData"), Http = Http,
                    Hardware = Hardware, Clipboard = Clipboard, Wevtutil = Wevtutil, CleanMgr = CleanMgr, Dism = Drivers, PnpUtil = Drivers, Shutdown = Shutdown,
                    Apps = apps,
                    Winget = new Core.Apps.Winget(Winget, Appx, Http, apps, Exe, Log, Folder("winget-temp"), Folder("Windows"), _ => { }),
                    UtcNow = () => Now, Sleep = _ => { },
                },
            };
        }

        /// <summary>A folder under the test's temp folder, made now.</summary>
        public string Folder(string name)
        {
            var p = Path.Combine(Dir, name);
            Directory.CreateDirectory(p);
            return p;
        }

        public void Dispose()
        {
            _key.Dispose();
            if (Directory.Exists(Dir)) Directory.Delete(Dir, recursive: true);
        }

        /// <summary>The test key under HKCU (Software\AkariTest\&lt;guid&gt;), for the PowerShell side of a test.</summary>
        public string KeyRoot => _key.Root;

        public static IReadOnlyList<Tweak> All => Loaded.Value.Tweaks;

        public Tweak Tweak(string id) => Engine.Find(id) ?? throw new KeyNotFoundException(id);

        public TweakState State(string id) => Engine.States.Of(Tweak(id));

        public Outcome Run(string id, TweakMode mode, object? value = null) => Engine.Runner.Run(Tweak(id), mode, value);

        public object? Get(string path, string name) => Engine.Registry.GetValue(path, name);

        public void Set(string path, string name, object value, string type) => Engine.Registry.SetValue(path, name, value, type);
    }

    internal sealed class FakePc : ISystemInfo
    {
        public int Build { get; set; } = 26100;
        public string Edition { get; set; } = "Professional";
        public Chassis Chassis { get; set; } = Chassis.Desktop;
        public IReadOnlyList<Gpu> Gpus { get; set; } = [];
        public IReadOnlyList<string> GpuDevices { get; set; } = [];
        public string? DisplayVersion { get; set; } = "24H2";
    }

    internal sealed class NoExplorer : IExplorer
    {
        public void Restart() { }
    }

    internal sealed class FakeHosts : IHostsFile
    {
        public List<string> Lines { get; set; } = [];
        public IReadOnlyList<string> Read() => Lines.ToList();
        public void Write(IReadOnlyList<string> lines) => Lines = lines.ToList();
    }

    /// <summary>Adapters' bindings by component id: one bool per adapter.</summary>
    internal sealed class FakeBindings : INetBindings
    {
        public Dictionary<string, List<bool>> On { get; } = [];
        public List<string> Calls { get; } = [];
        public IReadOnlyList<bool> Get(string componentId) => On.TryGetValue(componentId, out var b) ? b.ToList() : [];

        public void Set(string componentId, bool enabled)
        {
            Calls.Add($"{(enabled ? "+" : "-")}{componentId}");
            if (On.TryGetValue(componentId, out var b)) for (var i = 0; i < b.Count; i++) b[i] = enabled;
        }
    }

    internal sealed class FakeLauncher : ILauncher
    {
        public List<string> Opened { get; } = [];
        public void Open(string uri) => Opened.Add(uri);
    }

    /// <summary>Services by name: their start type; what was asked of them, in order.</summary>
    internal sealed class FakeServices : IServiceManager
    {
        public Dictionary<string, string> Installed { get; } = [];
        public List<string> Calls { get; } = [];
        public List<string> Stopped => Calls.Where(c => c.StartsWith("stop ", StringComparison.Ordinal)).Select(c => c[5..]).ToList();
        public string? StartType(string name) => Installed.GetValueOrDefault(name);
        public bool Stop(string name) { Calls.Add($"stop {name}"); return true; }
        public bool Start(string name) { Calls.Add($"start {name}"); return Installed.ContainsKey(name); }
        public void Create(string name, string binaryPath, bool automatic) { Calls.Add($"create {name} {binaryPath}"); Installed[name] = automatic ? "Automatic" : "Manual"; }
        public void Delete(string name) { Calls.Add($"delete {name}"); Installed.Remove(name); }
        public IReadOnlyList<string> Names() => Installed.Keys.ToList();
    }

    internal sealed class FakeTasks : ITaskScheduler
    {
        public Dictionary<ScheduledTask, bool> All { get; } = [];
        public List<ScheduledTask> Unregistered { get; } = [];
        public IReadOnlyList<ScheduledTask> Find(Func<string, bool> name) => All.Keys.Where(t => name(t.Name)).ToList();
        public void SetEnabled(ScheduledTask task, bool enabled) => All[task] = enabled;
        /// <summary>Tasks Windows keeps (Unregister says false for them).</summary>
        public HashSet<string> Kept { get; } = [];
        public bool Unregister(ScheduledTask task)
        {
            if (Kept.Contains(task.Name)) return false;
            Unregistered.Add(task);
            All.Remove(task);
            return true;
        }
    }

    /// <summary>Programs run: "path args"; Result decides what each returns (csc writes its out file).</summary>
    internal sealed class FakeExe : IExe
    {
        public List<string> Runs { get; } = [];
        public Func<string, string, ExeResult> Result { get; set; } = (_, _) => new(0, "");
        /// <summary>Every run with its full path: "path|arguments|wait|capture".</summary>
        public List<string> Full { get; } = [];
        public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true)
        {
            Runs.Add($"{Path.GetFileName(path)} {arguments}");
            Full.Add($"{path}|{arguments}|{wait}|{capture}");
            return Result(path, arguments);
        }
    }

    /// <summary>powercfg: the calls ("powercfg &lt;args&gt;"), and what it answers (by default nothing).</summary>
    internal sealed class FakePowerCfg : IPowerCfg
    {
        public List<string> Calls { get; } = [];
        public Func<string[], IReadOnlyList<string>> Answer { get; set; } = _ => [];
        public IReadOnlyList<string> Run(params string[] arguments) { Calls.Add($"powercfg {string.Join(" ", arguments)}"); return Answer(arguments); }
    }

    /// <summary>Running programs by name (each with a window); the ones stopped, in order.</summary>
    internal sealed class FakeProcesses : IProcesses
    {
        public List<string> Stopped { get; } = [];
        public List<string> Names { get; } = [];
        public void Stop(string name) => Stopped.Add(name);
        public IReadOnlyList<string> Running() => Names.ToList();
        public bool HasWindow(string name) => Names.Contains(name, StringComparer.OrdinalIgnoreCase);

        /// <summary>A running program's exe path (none given = unreadable).</summary>
        public Dictionary<string, string> Paths { get; } = new(StringComparer.OrdinalIgnoreCase);

        /// <summary>"name|seconds" for each program waited for.</summary>
        public List<string> Waited { get; } = [];

        public void Wait(string name, Func<string?, bool> path, TimeSpan timeout)
        {
            if (Names.Contains(name, StringComparer.OrdinalIgnoreCase) && path(Paths.GetValueOrDefault(name))) Waited.Add($"{name}|{timeout.TotalSeconds}");
        }
    }

    /// <summary>Downloads from a URL: "url|file", each writing an empty file there.</summary>
    internal sealed class FakeHttp : Core.Update.IHttp
    {
        public List<string> Saved { get; } = [];

        /// <summary>Pages read: "url" (" +headers" when some were given); their text from Pages ("" otherwise).</summary>
        public List<string> Read { get; } = [];
        public Dictionary<string, string> Pages { get; } = [];
        public List<IReadOnlyDictionary<string, string>> Headers { get; } = [];

        public void Download(string url, string file) => Download(url, file, null);

        public void Download(string url, string file, IReadOnlyDictionary<string, string>? headers)
        {
            if (headers is not null) Headers.Add(headers);
            Saved.Add($"{url}|{file}{(headers is null ? "" : " +headers")}");
            Directory.CreateDirectory(Path.GetDirectoryName(file)!);
            File.WriteAllText(file, "");
        }

        public string Text(string url, IReadOnlyDictionary<string, string>? headers = null)
        {
            if (headers is not null) Headers.Add(headers);
            Read.Add($"{url}{(headers is null ? "" : " +headers")}");
            return Pages.GetValueOrDefault(url, "");
        }
    }

    internal sealed class FakeHardware : IHardware
    {
        public BoardInfo? BoardIs { get; set; } = new("ASUSTeK COMPUTER INC.", "ROG STRIX B650E-F GAMING WIFI");
        public BiosInfo? BiosIs { get; set; } = new("3024", new DateTime(2024, 8, 5));
        public List<VolumeInfo> All { get; } = [];
        public IReadOnlyList<int> ChassisTypes() => [3];
        public IReadOnlyList<string> DisplayDeviceIds() => [];
        public BoardInfo? Board() => BoardIs;
        public BiosInfo? Bios() => BiosIs;
        public IReadOnlyList<VolumeInfo> Volumes() => All.ToList();
    }

    internal sealed class FakeClipboard : IClipboard
    {
        public List<string> Texts { get; } = [];
        public void SetText(string text) => Texts.Add(text);
    }

    /// <summary>wevtutil: "el" answers Logs; every call recorded ("wevtutil &lt;args&gt;").</summary>
    internal sealed class FakeWevtutil : IWevtutil
    {
        public List<string> Logs { get; } = [];
        public List<string> Calls { get; } = [];

        public IReadOnlyList<string> Run(params string[] arguments)
        {
            Calls.Add($"wevtutil {string.Join(" ", arguments)}");
            return arguments[0] == "el" ? Logs.ToList() : [];
        }
    }

    internal sealed class FakeCleanMgr : ICleanMgr
    {
        public List<int> Runs { get; } = [];
        public void Run(int set) => Runs.Add(set);
    }

    /// <summary>The driver store: its packages (DISM's list) and pnputil's deletes ("pnputil &lt;inf&gt;"; Kept = 1). Also
    /// the rest of DISM, empty.</summary>
    internal sealed class FakeDriverStore : Core.Apps.IDism, IPnpUtil
    {
        public List<Core.Apps.DriverPackage> Packages { get; } = [];
        public HashSet<string> Kept { get; } = [];
        public List<string> Calls { get; } = [];
        public IReadOnlyList<Core.Apps.DriverPackage> Drivers() => Packages.ToList();
        public int DeleteDriver(string inf) { Calls.Add($"pnputil {inf}"); return Kept.Contains(inf) ? 1 : 0; }
        public IReadOnlyList<Core.Apps.DismItem> Capabilities() => [];
        public IReadOnlyList<Core.Apps.DismItem> Features() => [];
        public string? CapabilityState(string name) => null;
        public string? FeatureState(string name) => null;
        public void RemoveCapability(string name) { }
        public void DisableFeature(string name) { }
    }

    internal sealed class FakeShutdown : IShutdown
    {
        public int Restarts { get; private set; }
        public int FirmwareRestarts { get; private set; }
        public int FirmwareCode { get; set; }
        public void Restart() => Restarts++;
        public int Firmware() { FirmwareRestarts++; return FirmwareCode; }
    }

    /// <summary>winget.exe: "--version" 1.9.0, installs recorded by id ("winget &lt;id&gt; &lt;source&gt;", as the blocks oracle
    /// writes them); OnInstall lays the package's files down.</summary>
    internal sealed class FakeWinget : Core.Apps.IWinget
    {
        public List<string> Installs { get; } = [];
        public Action<string>? OnInstall { get; set; }

        public Core.Apps.WingetResult Run(params string[] arguments)
        {
            if (arguments[0] == "--version") return new(0, ["v1.9.0"]);
            if (arguments[0] == "install")
            {
                var id = arguments[Array.IndexOf(arguments, "--id") + 1];
                var source = arguments[Array.IndexOf(arguments, "--source") + 1];
                Installs.Add($"winget {id} {source}");
                OnInstall?.Invoke(id);
            }
            return new(0, []);
        }
    }

    /// <summary>Store packages: none installed; Add-AppxPackage recorded ("appx &lt;file&gt;").</summary>
    internal sealed class FakeAppx : Core.Apps.IPackageManager
    {
        public List<string> Calls { get; } = [];
        public IReadOnlyList<Core.Apps.AppPackage> AllUsers() => [];
        public void Remove(string fullName) => Calls.Add($"remove {fullName}");
        public void RegisterByFamily(string family) => Calls.Add($"register-family {family}");
        public void Register(string manifest) => Calls.Add($"register {manifest}");
        public void Add(string file) => Calls.Add($"appx {file}");
        public IReadOnlyList<Core.Apps.ProvisionedApp> ProvisionedApps() => [];
        public void Deprovision(string family) => Calls.Add($"deprovision {family}");
    }

    internal sealed class CountingExplorer : IExplorer
    {
        public int Restarts { get; private set; }
        public void Restart() => Restarts++;
    }

    /// <summary>Shortcuts made: link -> target (the .lnk file written empty, so it exists).</summary>
    internal sealed class FakeShortcuts : IShortcuts
    {
        public Dictionary<string, string> Made { get; } = [];
        public Dictionary<string, string?> WorkingFolders { get; } = [];

        public void Create(string link, string target, string? workingDirectory = null)
        {
            Made[link] = target;
            WorkingFolders[link] = workingDirectory;
            Directory.CreateDirectory(Path.GetDirectoryName(link)!);
            File.WriteAllText(link, "");
        }
    }

    /// <summary>AkariOS-Files downloads: "name|out file", each writing an empty file there (so the program exists).</summary>
    internal sealed class FakeDownloads : IDownloads
    {
        public List<string> Saved { get; } = [];

        /// <summary>A file's own content: name -> a local file copied instead of an empty one (a zip).</summary>
        public Dictionary<string, string> Files { get; } = [];

        public void Save(string name, string outFile)
        {
            Saved.Add($"{name}|{outFile}");
            Directory.CreateDirectory(Path.GetDirectoryName(outFile)!);
            if (Files.TryGetValue(name, out var from)) File.Copy(from, outFile, overwrite: true);
            else File.WriteAllText(outFile, "");
        }
    }

    internal sealed class FakeDesktop : IDesktop
    {
        public List<string> Wallpapers { get; } = [];
        public (int Width, int Height) Size { get; set; } = (64, 36);
        public void SetWallpaper(string path) => Wallpapers.Add(path);
        public (int Width, int Height) ScreenSize() => Size;
    }

    internal sealed class FakeMemory : IMemoryAgent
    {
        /// <summary>Each feature on or off (Windows' own to start with), the operation recorder's file count, and the
        /// calls in the blocks oracle's words ("mmagent enable|disable &lt;feature&gt;", "mmagent set MaxOperationAPIFiles &lt;n&gt;").</summary>
        public Dictionary<string, bool> On { get; } = new(StringComparer.OrdinalIgnoreCase)
        {
            ["ApplicationLaunchPrefetching"] = true, ["ApplicationPreLaunch"] = true, ["OperationAPI"] = true, ["PageCombining"] = false, ["MemoryCompression"] = true,
        };
        public uint MaxFiles { get; set; } = 512;
        public List<string> Calls { get; } = [];
        public bool MemoryCompression => On["MemoryCompression"];

        public MemoryAgentState Get() => new(On["ApplicationLaunchPrefetching"], On["ApplicationPreLaunch"], On["OperationAPI"], On["PageCombining"], On["MemoryCompression"], MaxFiles);

        public void Set(string feature, bool on)
        {
            if (!On.ContainsKey(feature)) throw new ArgumentException(feature);
            Calls.Add($"mmagent {(on ? "enable" : "disable")} {feature}");
            On[feature] = on;
        }

        public void SetMaxOperationAPIFiles(uint count) { Calls.Add($"mmagent set MaxOperationAPIFiles {count}"); MaxFiles = count; }
    }

    internal sealed class FakeBitLocker : IBitLocker
    {
        public List<BitLockerVolume>? All { get; set; } = [];
        public List<string> Decrypting { get; } = [];
        public IReadOnlyList<BitLockerVolume>? Volumes() => All;
        public void Decrypt(BitLockerVolume volume) => Decrypting.Add(volume.MountPoint);
    }

    /// <summary>bcdedit: the calls ("bcdedit &lt;args&gt;", "bcd &lt;id&gt;" for a read), what /enum prints, the exit code.</summary>
    internal sealed class FakeBcd : IBcdEdit
    {
        public List<string> Calls { get; } = [];
        public List<string> Lines { get; set; } = [];
        public int ExitCode { get; set; }
        public IReadOnlyList<string> Read(string id) { Calls.Add($"bcd {id}"); return Lines.ToList(); }
        public int Run(string arguments) { Calls.Add($"bcdedit {arguments}"); return ExitCode; }
    }

    internal sealed class FakeW32tm : IW32tm
    {
        public List<string> Calls { get; } = [];
        public IReadOnlyList<string> Run(params string[] arguments) { Calls.Add($"w32tm {string.Join(" ", arguments)}"); return []; }
    }

    /// <summary>Store apps' settings hives by package family (the folder above Settings\settings.dat): their values, the
    /// ones the app holds (unreadable, refused), the imports ("family|text"). An import needs the settings.dat file, as
    /// the real one does, and its .reg text changes the values, so a Detect after it reads what it wrote.</summary>
    internal sealed class FakeAppSettings : IAppSettings
    {
        public Dictionary<string, Dictionary<string, byte[]>> Hives { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> Held { get; } = new(StringComparer.OrdinalIgnoreCase);
        public List<string> Imports { get; } = [];

        public static string Family(string dat) => Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(dat)))!;

        private Dictionary<string, byte[]> Values(string family) =>
            Hives.TryGetValue(family, out var v) ? v : Hives[family] = new(StringComparer.OrdinalIgnoreCase);

        public bool Import(string dat, string regText)
        {
            var family = Family(dat);
            if (!File.Exists(dat) || Held.Contains(family)) return false;
            Imports.Add($"{family}|{regText}");
            var values = Values(family);
            foreach (var key in RegReader.Parse(regText).Keys)
            {
                var rel = key.Path.Length == AppSettings.ImportRoot.Length ? "" : key.Path[(AppSettings.ImportRoot.Length + 1)..];
                foreach (var v in key.Values)
                {
                    var name = rel.Length == 0 ? v.Name : $@"{rel}\{v.Name}";
                    if (v.Delete) values.Remove(name);
                    else values[name] = v.Raw ?? (byte[])v.Data!;
                }
            }
            return true;
        }

        public IReadOnlyDictionary<string, byte[]>? Read(string dat)
        {
            var family = Family(dat);
            if (Held.Contains(family)) return null;
            return File.Exists(dat) ? new Dictionary<string, byte[]>(Values(family), StringComparer.OrdinalIgnoreCase) : new Dictionary<string, byte[]>();
        }
    }

    /// <summary>Runs the work at once and counts it (what ran as TrustedInstaller); programs started recorded, not run.</summary>
    internal sealed class FakeTrusted : ITrustedInstaller
    {
        public int Runs { get; private set; }
        public List<string> Started { get; } = [];
        public void Run(Action work) { Runs++; work(); }
        public int Start(string exe, string arguments) { Started.Add($"{exe}|{arguments}"); return 0; }
    }

    /// <summary>System Restore: the points made; Refuse = Windows says no.</summary>
    internal sealed class FakeRestore : ISystemRestore
    {
        public List<string> Made { get; } = [];
        public bool Refuse { get; set; }
        public IReadOnlyList<RestorePoint> List() => Made.Select((d, i) => new RestorePoint(d, null, (uint)i)).ToList();
        public void Create(string description) { if (Refuse) throw new InvalidOperationException("Windows refused the restore point"); Made.Add(description); }
        public void EnableProtection() { }
    }
}
