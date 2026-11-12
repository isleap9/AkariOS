using System.Diagnostics;
using System.Management;
using System.Text;
using AkariOS.Core.Apps;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;
using AkariOS.Core.Update;

namespace AkariOS.Core.Machine;

/// <summary>
/// What a Tweak's C# reaches beyond the registry, each behind an interface that tests fake (rule 12): the hosts file,
/// the network adapters' bindings, a settings page, services, scheduled tasks, programs, the memory agent, BitLocker,
/// the boot store, w32tm, Store apps' settings files, downloads, what Akari last did, TrustedInstaller, the system
/// folders, the clock. A part left null (or a folder left "") is one the engine doesn't have (a test that doesn't need
/// it): using it fails the Tweak.
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
    public IProcesses? Processes { get; init; }
    public IExplorer? Explorer { get; init; }
    public IShortcuts? Shortcuts { get; init; }
    public IDesktop? Desktop { get; init; }
    public IBcdEdit? BcdEdit { get; init; }
    public IW32tm? W32tm { get; init; }
    public IAppSettings? AppSettings { get; init; }
    public ITrustedInstaller? Trusted { get; init; }
    public IDownloads? Downloads { get; init; }

    /// <summary>System Restore (the restore point Action: through Runs.RestorePoints, as the GUI makes them).</summary>
    public Runs.ISystemRestore? SystemRestore { get; init; }

    /// <summary>Store apps, Optional features, Windows features (the Remove tab's engine; Appx.ps1).</summary>
    public AppPackages? Apps { get; init; }

    /// <summary>winget installs and the Microsoft Store (Winget.ps1): one per engine, so winget is checked once.</summary>
    public Winget? Winget { get; init; }

    /// <summary>What Akari last did to a Tweak it can't read back (state.json): the Engine's own.</summary>
    public IRememberedState? Remembered { get; init; }

    /// <summary>%ProgramData% (tests: a temp folder).</summary>
    public string ProgramData { get; init; } = "";

    /// <summary>%PUBLIC% (C:\Users\Public: the all-users desktop).</summary>
    public string Public { get; init; } = "";

    /// <summary>The process's own %LOCALAPPDATA% (the elevated account's: where winget, run from here, unpacks portable
    /// packages); not the real user's, which <see cref="UserFolders"/> gives.</summary>
    public string LocalAppData { get; init; } = "";

    /// <summary>Downloads from any URL (an extension a browser install adds); AkariOS-Files ones go through
    /// <see cref="Downloads"/>.</summary>
    public AkariOS.Core.Update.IHttp? Http { get; init; }

    /// <summary>%SystemRoot% (C:\Windows).</summary>
    public string Windows { get; init; } = "";

    /// <summary>%SystemDrive%\ (C:\).</summary>
    public string SystemDrive { get; init; } = "";

    /// <summary>%ProgramFiles% (C:\Program Files).</summary>
    public string ProgramFiles { get; init; } = "";

    /// <summary>%ProgramFiles(x86)% (C:\Program Files (x86)).</summary>
    public string ProgramFilesX86 { get; init; } = "";

    /// <summary>Where files a Tweak hands to a tool are written out first (%ProgramData%\AkariOS.Native\Files).</summary>
    public string FilesFolder { get; init; } = "";

    /// <summary>The Tools (N8): the board, BIOS and drives (WMI), the clipboard, event logs, Disk Cleanup, the driver
    /// store (DISM's list, pnputil's delete), the firmware restart.</summary>
    public IHardware? Hardware { get; init; }
    public IClipboard? Clipboard { get; init; }
    public IWevtutil? Wevtutil { get; init; }
    public ICleanMgr? CleanMgr { get; init; }
    public IDism? Dism { get; init; }
    public IPnpUtil? PnpUtil { get; init; }
    public IShutdown? Shutdown { get; init; }

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
    public static TweakServices Live(ITrustedInstaller trusted, IUserSid user, IExplorer explorer, IRememberedState remembered, IAkariLog log)
    {
        var windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        var services = new ServiceManager();
        var exe = new ExeRunner();
        var packages = new WindowsPackages();
        var dism = new DismApi();
        var apps = new AppPackages(packages, dism, log);
        var http = new HttpDownloads();
        return new()
        {
            Hardware = new WmiHardware(),
            Clipboard = new Clipboard(),
            Wevtutil = new WevtutilExe(),
            CleanMgr = new CleanMgrExe(),
            Dism = dism,
            PnpUtil = new PnpUtilExe(),
            Shutdown = new ShutdownExe(),
            Apps = apps,
            Winget = new Winget(new WingetExe(), packages, http, apps, exe, log, Path.GetTempPath(), windows, Thread.Sleep),
            Http = http,
            LocalAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            Hosts = new HostsFile(),
            Bindings = new WmiNetBindings(),
            Launcher = new ShellLauncher(),
            Services = services,
            BcdEdit = new BcdEdit(),
            W32tm = new W32tm(services),
            AppSettings = new RegExeAppSettings(),
            Tasks = new TaskScheduler(),
            Exe = exe,
            Memory = new WmiMemoryAgent(),
            BitLocker = new WmiBitLocker(),
            PowerCfg = new PowerCfg(),
            Processes = new Processes(),
            Explorer = explorer,
            Shortcuts = new Shortcuts(),
            Desktop = new Desktop(),
            Trusted = trusted,
            Downloads = new AkariFiles(),
            SystemRestore = new Runs.WmiSystemRestore(),
            Remembered = remembered,
            UserSid = user.Sid,
            ProgramData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            Public = Environment.GetEnvironmentVariable("PUBLIC") ?? "",
            Windows = windows,
            SystemDrive = Path.GetPathRoot(windows) ?? @"C:\",
            ProgramFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            ProgramFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
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

/// <summary>Opens a URI through the shell: a Settings page (ms-settings:), the Store's (ms-windows-store:), Windows
/// Security's (windowsdefender:), or a web page (https:, the Tools' tests and searches) in the default browser.</summary>
public interface ILauncher
{
    void Open(string uri);
}

/// <summary>The real one (guarded); only Settings, Store and Windows Security pages, and https web pages.</summary>
public sealed class ShellLauncher : ILauncher
{
    private static readonly string[] Schemes = ["ms-settings:", "ms-windows-store:", "windowsdefender:", "https:"];

    public ShellLauncher() => SystemGuard.Check("Opening Settings pages");

    public void Open(string uri)
    {
        if (!Schemes.Any(s => uri.StartsWith(s, StringComparison.OrdinalIgnoreCase)))
            throw new ArgumentException($"not a Settings or https page: {uri}");
        Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true })?.Dispose();
    }
}
