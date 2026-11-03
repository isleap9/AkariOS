using AkariOS.Core;
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
        public FakeTrusted Trusted { get; } = new();
        public FakePc Pc { get; } = new();
        public DateTime Now { get; set; } = new(2026, 11, 3, 12, 0, 0, DateTimeKind.Utc);
        public Engine Engine { get; }
        public MemoryLog Log { get; } = new();

        public TweakHarness()
        {
            Directory.CreateDirectory(Dir);
            var files = new FolderSourceFiles(Repo.Root);
            Engine = new Engine
            {
                Files = files,
                Registry = new RegistryEngine(_key.Paths, Trusted),
                System = Pc,
                Log = Log,
                Remembered = new JsonRememberedState(Path.Combine(Dir, "state.json")),
                Explorer = new NoExplorer(),
                Presets = new PresetStore(files, Path.Combine(Dir, "presets"), Path.Combine(Dir, "lastused.json"), Log),
                Codes = TweaksAssembly.Codes,
                IsAdmin = () => true,
                InSafeMode = () => false,
                Services = new TweakServices
                {
                    Hosts = Hosts, Bindings = Bindings, Launcher = Launcher, Services = Services, Tasks = Tasks, Exe = Exe,
                    Memory = Memory, BitLocker = BitLocker, PowerCfg = PowerCfg, Trusted = Trusted,
                    ProgramData = Folder("ProgramData"), Windows = Folder("Windows"), SystemDrive = Folder("C"), FilesFolder = Folder("Files"),
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
    }

    internal sealed class FakeTasks : ITaskScheduler
    {
        public Dictionary<ScheduledTask, bool> All { get; } = [];
        public IReadOnlyList<ScheduledTask> Find(Func<string, bool> name) => All.Keys.Where(t => name(t.Name)).ToList();
        public void SetEnabled(ScheduledTask task, bool enabled) => All[task] = enabled;
    }

    /// <summary>Programs run: "path args"; Result decides what each returns (csc writes its out file).</summary>
    internal sealed class FakeExe : IExe
    {
        public List<string> Runs { get; } = [];
        public Func<string, string, ExeResult> Result { get; set; } = (_, _) => new(0, "");
        public ExeResult Run(string path, string arguments, bool wait = true) { Runs.Add($"{Path.GetFileName(path)} {arguments}"); return Result(path, arguments); }
    }

    /// <summary>powercfg: the calls ("powercfg &lt;args&gt;"), and what it answers (by default nothing).</summary>
    internal sealed class FakePowerCfg : IPowerCfg
    {
        public List<string> Calls { get; } = [];
        public Func<string[], IReadOnlyList<string>> Answer { get; set; } = _ => [];
        public IReadOnlyList<string> Run(params string[] arguments) { Calls.Add($"powercfg {string.Join(" ", arguments)}"); return Answer(arguments); }
    }

    internal sealed class FakeMemory : IMemoryAgent
    {
        public bool MemoryCompression { get; set; } = true;
        public void SetMemoryCompression(bool on) => MemoryCompression = on;
    }

    internal sealed class FakeBitLocker : IBitLocker
    {
        public List<BitLockerVolume>? All { get; set; } = [];
        public List<string> Decrypting { get; } = [];
        public IReadOnlyList<BitLockerVolume>? Volumes() => All;
        public void Decrypt(BitLockerVolume volume) => Decrypting.Add(volume.MountPoint);
    }

    /// <summary>Runs the work at once and counts it (what ran as TrustedInstaller).</summary>
    internal sealed class FakeTrusted : ITrustedInstaller
    {
        public int Runs { get; private set; }
        public void Run(Action work) { Runs++; work(); }
    }
}
