using System.Diagnostics;
using System.Management;
using System.Text;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Machine;

/// <summary>
/// What a Tweak's C# reaches beyond the registry, each behind an interface that tests fake (rule 12): the hosts file,
/// the network adapters' bindings, a settings page, services, scheduled tasks, programs, the memory agent, BitLocker,
/// TrustedInstaller, the system folders, the clock. A part left null (or a folder left "") is one the engine doesn't
/// have (a test that doesn't need it): using it fails the Tweak.
/// </summary>
public sealed class TweakServices
{
    public IHostsFile? Hosts { get; init; }
    public INetBindings? Bindings { get; init; }
    public ILauncher? Launcher { get; init; }
    public IServiceManager? Services { get; init; }
    public ITaskScheduler? Tasks { get; init; }
    public IExe? Exe { get; init; }
    public IMemoryAgent? Memory { get; init; }
    public IBitLocker? BitLocker { get; init; }
    public IPowerCfg? PowerCfg { get; init; }
    public ITrustedInstaller? Trusted { get; init; }

    /// <summary>%ProgramData% (tests: a temp folder).</summary>
    public string ProgramData { get; init; } = "";

    /// <summary>%SystemRoot% (C:\Windows).</summary>
    public string Windows { get; init; } = "";

    /// <summary>%SystemDrive%\ (C:\).</summary>
    public string SystemDrive { get; init; } = "";

    /// <summary>Where files a Tweak hands to a tool are written out first (%ProgramData%\AkariOS.Native\Files).</summary>
    public string FilesFolder { get; init; } = "";

    /// <summary>The logged-in user's SID (their profile folder, when Shell Folders doesn't say).</summary>
    public string? UserSid { get; init; }

    public Func<DateTime> UtcNow { get; init; } = () => DateTime.UtcNow;

    /// <summary>A pause a block takes (Start-Sleep); tests take none.</summary>
    public Action<TimeSpan> Sleep { get; init; } = Thread.Sleep;

    public static T Need<T>(T? part, string what) where T : class =>
        part ?? throw new NotSupportedException($"this engine has no {what}");

    /// <summary>A folder, or a failure when the engine has none.</summary>
    public static string Folder(string folder, string what) =>
        folder.Length > 0 ? folder : throw new NotSupportedException($"this engine has no {what} folder");

    /// <summary>The real ones (guarded).</summary>
    public static TweakServices Live(ITrustedInstaller trusted, IUserSid user)
    {
        var windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        return new()
        {
            Hosts = new HostsFile(),
            Bindings = new WmiNetBindings(),
            Launcher = new ShellLauncher(),
            Services = new ServiceManager(),
            Tasks = new TaskScheduler(),
            Exe = new ExeRunner(),
            Memory = new WmiMemoryAgent(),
            BitLocker = new WmiBitLocker(),
            PowerCfg = new PowerCfg(),
            Trusted = trusted,
            UserSid = user.Sid,
            ProgramData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            Windows = windows,
            SystemDrive = Path.GetPathRoot(windows) ?? @"C:\",
            FilesFolder = Path.Combine(AkariPaths.MachineFolder, "Files"),
        };
    }
}

/// <summary>The hosts file's lines ($AkariHostsPath).</summary>
public interface IHostsFile
{
    /// <summary>Its lines; none when there is no file.</summary>
    IReadOnlyList<string> Read();

    void Write(IReadOnlyList<string> lines);
}

/// <summary>Akari's named blocks in the hosts file (Get- / Set-AkariHostsBlock): "# AkariOS &lt;name&gt; start" … "end"; the
/// user's lines untouched. Pure, on the lines.</summary>
public static class HostsBlocks
{
    /// <summary>The block's lines, or null when there is none.</summary>
    public static IReadOnlyList<string>? Get(IReadOnlyList<string> all, string name)
    {
        var (s, e) = Find(all, name);
        return s < 0 || e < s ? null : all.Skip(s + 1).Take(e - s - 1).ToList();
    }

    /// <summary>The file with the block at its end (replacing it if there); no lines = the block removed.</summary>
    public static IReadOnlyList<string> Set(IReadOnlyList<string> all, string name, IReadOnlyList<string> lines)
    {
        var list = all.ToList();
        var (s, e) = Find(list, name);
        if (s >= 0 && e >= s) list.RemoveRange(s, e - s + 1);
        if (lines.Count > 0) list.AddRange([$"# AkariOS {name} start", .. lines, $"# AkariOS {name} end"]);
        return list;
    }

    private static (int Start, int End) Find(IReadOnlyList<string> all, string name)
    {
        var list = all.ToList();
        return (list.IndexOf($"# AkariOS {name} start"), list.IndexOf($"# AkariOS {name} end"));
    }
}

/// <summary>The real hosts file, written in ASCII as the PowerShell app writes it (guarded).</summary>
public sealed class HostsFile : IHostsFile
{
    private static readonly string Path = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "drivers", "etc", "hosts");

    public HostsFile() => SystemGuard.Check("The hosts file");

    public IReadOnlyList<string> Read() => File.Exists(Path) ? File.ReadAllLines(Path) : [];

    public void Write(IReadOnlyList<string> lines) => File.WriteAllLines(Path, lines, Encoding.ASCII);
}

/// <summary>A protocol's binding on every network adapter (Get- / Enable- / Disable-NetAdapterBinding).</summary>
public interface INetBindings
{
    /// <summary>Whether it is on, one per adapter that has it.</summary>
    IReadOnlyList<bool> Get(string componentId);

    /// <summary>Turns it on or off on every adapter that has it; a protocol no adapter has is nothing to do.</summary>
    void Set(string componentId, bool enabled);
}

/// <summary>The real one: MSFT_NetAdapterBindingSettingData (root\StandardCimv2), what the NetAdapter cmdlets use (guarded).</summary>
public sealed class WmiNetBindings : INetBindings
{
    public WmiNetBindings() => SystemGuard.Check("Network adapter bindings");

    private static ManagementObjectCollection Query(string componentId)
    {
        var scope = new ManagementScope(@"root\StandardCimv2");
        var q = new ObjectQuery($"SELECT * FROM MSFT_NetAdapterBindingSettingData WHERE ComponentID = '{componentId.Replace("'", "")}'");
        return new ManagementObjectSearcher(scope, q).Get();
    }

    public IReadOnlyList<bool> Get(string componentId)
    {
        using var all = Query(componentId);
        return all.Cast<ManagementObject>().Select(b => b["Enabled"] is true).ToList();
    }

    public void Set(string componentId, bool enabled)
    {
        using var all = Query(componentId);
        foreach (var b in all.Cast<ManagementObject>())
            using (b) b.InvokeMethod(enabled ? "Enable" : "Disable", null);
    }
}

/// <summary>Opens a URI through the shell: a Settings page (ms-settings:).</summary>
public interface ILauncher
{
    void Open(string uri);
}

/// <summary>The real one (guarded); only ms-settings: pages.</summary>
public sealed class ShellLauncher : ILauncher
{
    public ShellLauncher() => SystemGuard.Check("Opening Settings pages");

    public void Open(string uri)
    {
        if (!uri.StartsWith("ms-settings:", StringComparison.OrdinalIgnoreCase)) throw new ArgumentException($"not a Settings page: {uri}");
        Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true })?.Dispose();
    }
}
