using System.Security.Principal;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core;

/// <summary>
/// The engine's parts, made once and handed to the CLI and the GUI: the shared files, the registry, the machine,
/// the loaded Tweaks, State, the Runner, presets, restore points. <see cref="Live"/> makes the real ones; tests make
/// their own (a test key, fixture files, fakes).
/// </summary>
public sealed class Engine
{
    public required ISourceFiles Files { get; init; }
    public required RegistryEngine Registry { get; init; }
    public required ISystemInfo System { get; init; }
    public required IAkariLog Log { get; init; }
    public required IRememberedState Remembered { get; init; }
    public required IExplorer Explorer { get; init; }
    public required PresetStore Presets { get; init; }
    public required IReadOnlyDictionary<string, ITweakCode> Codes { get; init; }
    public required Func<bool> IsAdmin { get; init; }
    public ISystemRestore? SystemRestore { get; init; }
    public IShutdown? Shutdown { get; init; }

    /// <summary>run.json and the next boot: with both, a Run can go into Safe Mode and on across restarts.</summary>
    public IRunStore? RunStore { get; init; }
    public IRunBoot? RunBoot { get; init; }

    private readonly ISafeModeHandoff? _safeMode;

    /// <summary>Where the Runner sends SafeMode Tweaks met outside Safe Mode: a Run in phases, unless a test sets its own.</summary>
    public ISafeModeHandoff? SafeMode
    {
        get => _safeMode ?? (RunStore != null && RunBoot != null ? new SafeModeHandoff(Phases, Services.UserSid ?? "") : null);
        init => _safeMode = value;
    }

    /// <summary>What Tweak classes reach beyond the registry (the hosts file, network bindings, ...).</summary>
    public TweakServices Services { get; init; } = new();

    /// <summary>Windows runs in Safe Mode (it sets SAFEBOOT_OPTION then; Test-AkariSafeMode).</summary>
    public Func<bool> InSafeMode { get; init; } = () => !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("SAFEBOOT_OPTION"));

    private LoadResult? _loaded;

    /// <summary>The Tweaks, read once.</summary>
    public LoadResult Loaded => _loaded ??= new Loader(Files, Codes).Load();

    public TweakContext Context => new(Registry, System, Files, Log, Services);

    public States States => new(Context, Remembered);

    public Runner Runner => new(Context, States, Remembered, Explorer, SafeMode, InSafeMode, Expected);

    /// <summary>expected.json (X3: the drift check); null = not recorded (tests unless they set one).</summary>
    public ExpectedStore? Expected { get; init; }

    /// <summary>The Run history Undo reads (X4); null = none kept (tests unless they set one).</summary>
    public RunHistory? History { get; init; }

    public RestorePoints? RestorePoints => SystemRestore is null ? null : new(SystemRestore, Registry, Log);

    /// <summary>A Tweak or Entry by id (an Entry of something on this PC is built from its id).</summary>
    public Tweak? Find(string id) => Loaded.Find(id) ?? Loader.ResolveEntry(Loaded.Groups, id);

    /// <summary>A Run in phases on this engine (Start-AkariPhases); throws when the engine has no run.json or next boot.</summary>
    public Phases Phases() => new(new PhaseParts
    {
        Find = Find,
        State = States.Of,
        System = System,
        InSafeMode = InSafeMode,
        Plan = items => Runner.Run(items, Find),
        History = History,
        Prepare = (t, i) => Runner.Prepare(t, i.Mode),
        Store = RunStore ?? throw new InvalidOperationException("this engine has no run.json"),
        Boot = RunBoot ?? throw new InvalidOperationException("this engine can't set up the next boot"),
        Log = Log,
    });

    /// <summary>
    /// The real machine (guarded: never in a test). Codes: AkariOS.Tweaks' classes. Sid: the user a resumed Run started
    /// for (its HKCU), else the session's.
    /// </summary>
    public static Engine Live(IReadOnlyDictionary<string, ITweakCode> codes, IAkariLog log, string? sid = null)
    {
        var trusted = new TrustedInstaller();
        var user = new RealUserSid(string.IsNullOrEmpty(sid) ? null : sid);
        var explorer = new ExplorerShell();
        var registry = new RegistryEngine(new LiveRegistryPaths(user), trusted);
        var remembered = new JsonRememberedState(AkariPaths.StateFile);
        var shutdown = new ShutdownExe();
        var services = TweakServices.Live(trusted, user, explorer, remembered, log);
        var boot = new RunBoot(registry, services.BcdEdit!, shutdown, () => SelfCopy.Live().Target(), Thread.Sleep);
        return new Engine
        {
            Files = new EmbeddedSourceFiles(),
            Registry = registry,
            System = new MachineInfo(registry, new WmiHardware()),
            Log = log,
            Remembered = remembered,
            Expected = new ExpectedStore(Path.Combine(AkariPaths.UserFolder, "expected.json")),
            History = new RunHistory(Path.Combine(AkariPaths.UserFolder, "history"), registry, log),
            Explorer = explorer,
            Presets = new PresetStore(new EmbeddedSourceFiles(), AkariPaths.PresetFolder, Path.Combine(AkariPaths.UserFolder, "lastused.json"), log),
            Codes = codes,
            IsAdmin = () => new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator),
            SystemRestore = services.SystemRestore,
            Shutdown = shutdown,
            Services = services,
            RunStore = new RunStore(Runs.RunStore.Default, boot.ClearResume),
            RunBoot = boot,
        };
    }
}
