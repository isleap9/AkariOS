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
    public ISafeModeHandoff? SafeMode { get; init; }

    private LoadResult? _loaded;

    /// <summary>The Tweaks, read once.</summary>
    public LoadResult Loaded => _loaded ??= new Loader(Files, Codes).Load();

    public TweakContext Context => new(Registry, System, Files, Log);

    public States States => new(Context, Remembered);

    public Runner Runner => new(Context, States, Remembered, Explorer, SafeMode);

    public RestorePoints? RestorePoints => SystemRestore is null ? null : new(SystemRestore, Registry, Log);

    /// <summary>A Tweak or Entry by id (an Entry of something on this PC is built from its id).</summary>
    public Tweak? Find(string id) => Loaded.Find(id) ?? Loader.ResolveEntry(Loaded.Groups, id);

    /// <summary>The real machine (guarded: never in a test). Codes: AkariOS.Tweaks' classes.</summary>
    public static Engine Live(IReadOnlyDictionary<string, ITweakCode> codes, IAkariLog log)
    {
        var registry = new RegistryEngine(new LiveRegistryPaths(new RealUserSid()), new TrustedInstaller());
        return new Engine
        {
            Files = new EmbeddedSourceFiles(),
            Registry = registry,
            System = new MachineInfo(registry, new WmiHardware()),
            Log = log,
            Remembered = new JsonRememberedState(AkariPaths.StateFile),
            Explorer = new ExplorerShell(),
            Presets = new PresetStore(new EmbeddedSourceFiles(), AkariPaths.PresetFolder, Path.Combine(AkariPaths.UserFolder, "lastused.json"), log),
            Codes = codes,
            IsAdmin = () => new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator),
            SystemRestore = new WmiSystemRestore(),
        };
    }
}
