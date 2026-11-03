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
        public FakeStopper Stopper { get; } = new();
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
                    Hosts = Hosts, Bindings = Bindings, Launcher = Launcher, Services = Stopper, Trusted = Trusted,
                    ProgramData = Path.Combine(Dir, "ProgramData"), UtcNow = () => Now,
                },
            };
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

    internal sealed class FakeStopper : IServiceStopper
    {
        public List<string> Stopped { get; } = [];
        public bool Stop(string name) { Stopped.Add(name); return true; }
    }

    /// <summary>Runs the work at once and counts it (what ran as TrustedInstaller).</summary>
    internal sealed class FakeTrusted : ITrustedInstaller
    {
        public int Runs { get; private set; }
        public void Run(Action work) { Runs++; work(); }
    }
}
