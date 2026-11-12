using System.ComponentModel;
using System.Diagnostics;
using System.Management;
using System.Runtime.InteropServices;
using System.ServiceProcess;

namespace AkariOS.Core.Machine;

// The rest of TweakServices' parts: an interface each (tests fake them) and the real one, guarded (rule 12).

/// <summary>Windows services one by one (Get- / Start- / Stop- / New-Service, sc delete). N6's Services page adds to it.</summary>
public interface IServiceManager
{
    /// <summary>Its start type (Automatic, Manual, Disabled, Boot, System), or null when the service isn't on this PC.</summary>
    string? StartType(string name);

    /// <summary>False when it isn't on this PC or won't stop (the PowerShell app goes on silently too).</summary>
    bool Stop(string name);

    /// <summary>False when it isn't on this PC or won't start.</summary>
    bool Start(string name);

    /// <summary>A new service (its display name = its name), started automatically or on demand.</summary>
    void Create(string name, string binaryPath, bool automatic);

    /// <summary>Removes it (sc delete); nothing to do when it isn't there.</summary>
    void Delete(string name);

    /// <summary>Every service's name (Get-Service).</summary>
    IReadOnlyList<string> Names();

    /// <summary>Get-AkariServices: every service with its display name, description, startup type, status and
    /// whether it accepts a stop (the Services page).</summary>
    IReadOnlyList<Tweaks.ServiceInfo> All() => throw new NotSupportedException("this service manager can't list services");

    /// <summary>One service as All gives it, or null when it isn't on this PC.</summary>
    Tweaks.ServiceInfo? One(string name) => throw new NotSupportedException("this service manager can't read a service");

    /// <summary>Invoke-AkariServiceControl: starts it, or stops it with the services that depend on it, waiting for
    /// it; throws when it won't.</summary>
    void Control(string name, string op) => throw new NotSupportedException("this service manager can't start or stop services");
}

/// <summary>The real one: the service control manager (guarded).</summary>
public sealed partial class ServiceManager : IServiceManager
{
    public ServiceManager() => SystemGuard.Check("Services");

    public IReadOnlyList<string> Names()
    {
        var all = ServiceController.GetServices();
        try { return all.Select(s => s.ServiceName).ToList(); }
        finally { foreach (var s in all) s.Dispose(); }
    }

    // Win32_Service, as Get-AkariServices reads it (the description and DelayedAutoStart in one query)
    private static IReadOnlyList<Tweaks.ServiceInfo> Query(string? name)
    {
        var wql = "SELECT Name, DisplayName, Description, StartMode, DelayedAutoStart, State, AcceptStop FROM Win32_Service"
            + (name is null ? "" : $" WHERE Name = '{name.Replace("\\", "\\\\", StringComparison.Ordinal).Replace("'", "\\'", StringComparison.Ordinal)}'");
        using var searcher = new ManagementObjectSearcher(wql);
        using var found = searcher.Get();
        return found.Cast<ManagementObject>().Select(s =>
        {
            using (s)
                return new Tweaks.ServiceInfo((string?)s["Name"] ?? "", (string?)s["DisplayName"] ?? "", (string?)s["Description"] ?? "",
                    Tweaks.ServiceLists.StartType((string?)s["StartMode"] ?? "", s["DelayedAutoStart"] is true), (string?)s["State"] ?? "", s["AcceptStop"] is true);
        }).ToList();
    }

    public IReadOnlyList<Tweaks.ServiceInfo> All() => Query(null);

    public Tweaks.ServiceInfo? One(string name) => Query(name).FirstOrDefault();

    public void Control(string name, string op)
    {
        using var sc = new ServiceController(name);
        if (op == "Start")
        {
            sc.Start();
            sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30));
        }
        else
        {
            sc.Stop(stopDependentServices: true);
            sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
        }
    }

    public string? StartType(string name)
    {
        try
        {
            using var sc = new ServiceController(name);
            return sc.StartType.ToString();
        }
        catch (InvalidOperationException) { return null; }
    }

    public bool Stop(string name)
    {
        try
        {
            using var sc = new ServiceController(name);
            if (sc.Status == ServiceControllerStatus.Stopped) return true;
            sc.Stop(stopDependentServices: true);
            sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(15));
            return true;
        }
        catch (Exception e) when (e is InvalidOperationException or Win32Exception or System.ServiceProcess.TimeoutException) { return false; }
    }

    public bool Start(string name)
    {
        try
        {
            using var sc = new ServiceController(name);
            if (sc.Status == ServiceControllerStatus.Running) return true;
            sc.Start();
            sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(15));
            return true;
        }
        catch (Exception e) when (e is InvalidOperationException or Win32Exception or System.ServiceProcess.TimeoutException) { return false; }
    }

    private const uint ScManagerAll = 0xF003F, ServiceAll = 0xF01FF, OwnProcess = 0x10, AutoStart = 2, DemandStart = 3, ErrorNormal = 1;

    public void Create(string name, string binaryPath, bool automatic)
    {
        var scm = OpenSCManagerW(null, null, ScManagerAll);
        if (scm == 0) throw new Win32Exception();
        try
        {
            var h = CreateServiceW(scm, name, name, ServiceAll, OwnProcess, automatic ? AutoStart : DemandStart, ErrorNormal, binaryPath, null, 0, null, null, null);
            if (h == 0) throw new Win32Exception();
            CloseServiceHandle(h);
        }
        finally { CloseServiceHandle(scm); }
    }

    public void Delete(string name)
    {
        var scm = OpenSCManagerW(null, null, ScManagerAll);
        if (scm == 0) throw new Win32Exception();
        try
        {
            var h = OpenServiceW(scm, name, ServiceAll);
            if (h == 0) return;
            try { if (!DeleteService(h)) throw new Win32Exception(); }
            finally { CloseServiceHandle(h); }
        }
        finally { CloseServiceHandle(scm); }
    }

    [LibraryImport("advapi32.dll", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint OpenSCManagerW(string? machine, string? database, uint access);

    [LibraryImport("advapi32.dll", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint CreateServiceW(nint scm, string name, string display, uint access, uint type, uint start, uint error,
        string binaryPath, string? loadOrderGroup, nint tagId, string? dependencies, string? account, string? password);

    [LibraryImport("advapi32.dll", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint OpenServiceW(nint scm, string name, uint access);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DeleteService(nint service);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CloseServiceHandle(nint handle);
}

/// <summary>A scheduled task: its folder (\Microsoft\Windows\Defrag) and name.</summary>
public sealed record ScheduledTask(string Folder, string Name);

/// <summary>Scheduled tasks (Get- / Enable- / Disable-ScheduledTask). N6's Scheduled tasks page adds to it.</summary>
public interface ITaskScheduler
{
    /// <summary>Every task, hidden ones too, whose name matches.</summary>
    IReadOnlyList<ScheduledTask> Find(Func<string, bool> name);

    void SetEnabled(ScheduledTask task, bool enabled);

    /// <summary>Deletes it (Unregister-ScheduledTask): true when it is gone (one already gone too), false when Windows
    /// keeps it.</summary>
    bool Unregister(ScheduledTask task);

    /// <summary>Get-AkariTasks: every task, hidden ones too, with its folder (a trailing \), state, description and
    /// author (resource strings resolved).</summary>
    IReadOnlyList<Tweaks.TaskInfo> All() => throw new NotSupportedException("this task scheduler can't list tasks");

    /// <summary>One task as All gives it, or null when it isn't on this PC.</summary>
    Tweaks.TaskInfo? One(string path, string name) => throw new NotSupportedException("this task scheduler can't read a task");
}

/// <summary>The real one: the Task Scheduler's COM API (Schedule.Service; guarded).</summary>
public sealed partial class TaskScheduler : ITaskScheduler
{
    // IRegisteredTask.State as Get-ScheduledTask names it
    private static string StateName(int s) => s switch { 1 => "Disabled", 2 => "Queued", 3 => "Ready", 4 => "Running", _ => "Unknown" };

    private static Tweaks.TaskInfo Info(dynamic folder, dynamic t)
    {
        string path = folder.Path;
        string description = "", author = "";
        try
        {
            dynamic info = t.Definition.RegistrationInfo;
            description = IndirectString((string?)info.Description ?? "");
            author = IndirectString((string?)info.Author ?? "");
        }
        catch (COMException) { }
        var state = StateName((int)t.State);
        return new Tweaks.TaskInfo(path.EndsWith('\\') ? path : path + "\\", (string)t.Name, state != "Disabled", state, description, author);
    }

    public IReadOnlyList<Tweaks.TaskInfo> All()
    {
        var found = new List<Tweaks.TaskInfo>();
        void Walk(dynamic folder)
        {
            foreach (dynamic t in folder.GetTasks(1)) found.Add(Info(folder, t));
            foreach (dynamic f in folder.GetFolders(0)) Walk(f);
        }
        Walk(Connect().GetFolder(@"\"));
        return found;
    }

    public Tweaks.TaskInfo? One(string path, string name)
    {
        try
        {
            dynamic folder = Connect().GetFolder(FolderOf(path));
            return Info(folder, folder.GetTask(name));
        }
        catch (COMException) { return null; }
    }

    /// <summary>A TaskInfo path ("\Microsoft\Windows\X\") as the COM API's folder ("\Microsoft\Windows\X", root "\").</summary>
    public static string FolderOf(string path) => path.Length > 1 ? path.TrimEnd('\\') : @"\";

    /// <summary>Resolve-AkariIndirectString: "@%SystemRoot%\x.dll,-101" or Task Scheduler's "$(@...)" as text; other
    /// text as it is; "" when it can't be loaded.</summary>
    public static string IndirectString(string text)
    {
        var t = text;
        if (t.StartsWith("$(@", StringComparison.Ordinal) && t.EndsWith(')')) t = t[2..^1];
        if (!t.StartsWith('@')) return text;
        var buf = new char[1024];
        unsafe
        {
            fixed (char* b = buf)
                return SHLoadIndirectString(t, b, buf.Length, 0) == 0 ? new string(b) : "";
        }
    }

    [LibraryImport("shlwapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static unsafe partial int SHLoadIndirectString(string source, char* buffer, int size, nint reserved);

    public TaskScheduler() => SystemGuard.Check("Scheduled tasks");

    private static dynamic Connect()
    {
        dynamic s = Activator.CreateInstance(Type.GetTypeFromProgID("Schedule.Service", throwOnError: true)!)!;
        s.Connect();
        return s;
    }

    public IReadOnlyList<ScheduledTask> Find(Func<string, bool> name)
    {
        var found = new List<ScheduledTask>();
        void Walk(dynamic folder)
        {
            // 1 = hidden tasks too
            foreach (dynamic t in folder.GetTasks(1)) if (name((string)t.Name)) found.Add(new ScheduledTask((string)folder.Path, (string)t.Name));
            foreach (dynamic f in folder.GetFolders(0)) Walk(f);
        }
        Walk(Connect().GetFolder(@"\"));
        return found;
    }

    public void SetEnabled(ScheduledTask task, bool enabled)
    {
        dynamic t = Connect().GetFolder(task.Folder).GetTask(task.Name);
        t.Enabled = enabled;
    }

    public bool Unregister(ScheduledTask task)
    {
        try { Connect().GetFolder(task.Folder).DeleteTask(task.Name, 0); return true; }
        // not there (any more): gone all the same
        catch (COMException e) { return e.HResult == unchecked((int)0x80070002); }
    }
}

/// <summary>What a program wrote and its exit code.</summary>
public sealed record ExeResult(int ExitCode, string Output);

/// <summary>A program a Tweak runs (Task Manager, Disk Cleanup, the .NET Framework compiler; Invoke-AkariExe).</summary>
public interface IExe
{
    /// <summary>Runs it; waiting = for it to end (its exit code and output), else 0 at once. capture = false: an
    /// installer (Start-Process -Wait): its own window, its output not read, waited for alone (a program it starts,
    /// holding the output pipes, would keep a capture waiting).</summary>
    ExeResult Run(string path, string arguments, bool wait = true, bool capture = true);
}

/// <summary>The real one (guarded).</summary>
public sealed class ExeRunner : IExe
{
    public ExeRunner() => SystemGuard.Check("Running programs");

    public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true)
    {
        var read = wait && capture;
        var psi = new ProcessStartInfo(path, arguments) { UseShellExecute = !read, RedirectStandardOutput = read, RedirectStandardError = read, CreateNoWindow = read };
        using var p = Process.Start(psi) ?? throw new InvalidOperationException($"{path} did not start");
        if (!wait) return new ExeResult(0, "");
        if (!read)
        {
            p.WaitForExit();
            return new ExeResult(p.ExitCode, "");
        }
        var err = p.StandardError.ReadToEndAsync();
        var output = p.StandardOutput.ReadToEnd();
        p.WaitForExit();
        return new ExeResult(p.ExitCode, output + err.Result);
    }
}

/// <summary>The only powercfg call (Invoke-AkariPowerCfg): its output lines, errors included as text (a setting this PC
/// doesn't have is no failure).</summary>
public interface IPowerCfg
{
    IReadOnlyList<string> Run(params string[] arguments);
}

/// <summary>The real one: %SystemRoot%\System32\powercfg.exe (guarded).</summary>
public sealed class PowerCfg : IPowerCfg
{
    public PowerCfg() => SystemGuard.Check("powercfg");

    public IReadOnlyList<string> Run(params string[] arguments)
    {
        var psi = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "powercfg.exe"))
        { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        foreach (var a in arguments) psi.ArgumentList.Add(a);
        using var p = Process.Start(psi) ?? throw new InvalidOperationException("powercfg did not start");
        var err = p.StandardError.ReadToEndAsync();
        var output = p.StandardOutput.ReadToEnd();
        p.WaitForExit();
        return (output + err.Result).Split(["\r\n", "\n"], StringSplitOptions.None).Where(l => l.Length > 0).ToList();
    }
}

/// <summary>What Get-MMAgent prints.</summary>
public sealed record MemoryAgentState(bool ApplicationLaunchPrefetching, bool ApplicationPreLaunch, bool OperationAPI, bool PageCombining,
    bool MemoryCompression, uint MaxOperationAPIFiles);

/// <summary>Windows' memory manager agent (Get- / Enable- / Disable- / Set-MMAgent).</summary>
public interface IMemoryAgent
{
    MemoryAgentState Get();

    /// <summary>Enable- / Disable-MMAgent -&lt;feature&gt;: ApplicationLaunchPrefetching, ApplicationPreLaunch,
    /// OperationAPI, PageCombining, MemoryCompression.</summary>
    void Set(string feature, bool on);

    /// <summary>Set-MMAgent -MaxOperationAPIFiles.</summary>
    void SetMaxOperationAPIFiles(uint count);
}

/// <summary>The real one: what the MMAgent cmdlets call, PS_MMAgent's static methods (root\Microsoft\Windows\PS_MMAgent; guarded).</summary>
public sealed class WmiMemoryAgent : IMemoryAgent
{
    public static readonly string[] Features = ["ApplicationLaunchPrefetching", "ApplicationPreLaunch", "OperationAPI", "PageCombining", "MemoryCompression"];

    public WmiMemoryAgent() => SystemGuard.Check("The memory agent");

    private static ManagementClass Class() => new(@"root\Microsoft\Windows\PS_MMAgent", "PS_MMAgent", null);

    public MemoryAgentState Get()
    {
        using var c = Class();
        using var result = c.InvokeMethod("Get", null, null);
        var o = result["CmdletOutput"] as ManagementBaseObject ?? throw new InvalidOperationException("Get-MMAgent printed nothing");
        bool On(string name) => o[name] is true;
        return new(On("ApplicationLaunchPrefetching"), On("ApplicationPreLaunch"), On("OperationAPI"), On("PageCombining"), On("MemoryCompression"),
            Convert.ToUInt32(o["MaxOperationAPIFiles"] ?? 0u, System.Globalization.CultureInfo.InvariantCulture));
    }

    public void Set(string feature, bool on)
    {
        if (!Features.Contains(feature)) throw new ArgumentException($"not a memory agent feature: {feature}");
        Invoke(on ? "Enable" : "Disable", feature, true);
    }

    public void SetMaxOperationAPIFiles(uint count) => Invoke("Set", "MaxOperationAPIFiles", count);

    private static void Invoke(string method, string parameter, object value)
    {
        using var c = Class();
        using var args = c.GetMethodParameters(method);
        args[parameter] = value;
        using var _ = c.InvokeMethod(method, args, null);
    }
}

/// <summary>A BitLocker volume: its id, its mount point (C:), protection on, fully decrypted.</summary>
public sealed record BitLockerVolume(string Id, string MountPoint, bool ProtectionOn, bool FullyDecrypted);

/// <summary>BitLocker (Get-BitLockerVolume, Disable-BitLocker).</summary>
public interface IBitLocker
{
    /// <summary>Every encryptable volume, or null when this edition of Windows has no BitLocker.</summary>
    IReadOnlyList<BitLockerVolume>? Volumes();

    /// <summary>Starts decrypting it (Windows goes on in the background).</summary>
    void Decrypt(BitLockerVolume volume);
}

/// <summary>The real one: Win32_EncryptableVolume (root\CIMV2\Security\MicrosoftVolumeEncryption; guarded).</summary>
public sealed class WmiBitLocker : IBitLocker
{
    public WmiBitLocker() => SystemGuard.Check("BitLocker");

    private static ManagementObjectCollection Query() =>
        new ManagementObjectSearcher(new ManagementScope(@"root\CIMV2\Security\MicrosoftVolumeEncryption"), new ObjectQuery("SELECT * FROM Win32_EncryptableVolume")).Get();

    public IReadOnlyList<BitLockerVolume>? Volumes()
    {
        try
        {
            using var all = Query();
            return all.Cast<ManagementObject>().Select(v =>
            {
                using (v)
                {
                    using var status = v.InvokeMethod("GetConversionStatus", null, null);
                    var conversion = Convert.ToUInt32(status["ConversionStatus"], System.Globalization.CultureInfo.InvariantCulture);
                    var protection = Convert.ToUInt32(v["ProtectionStatus"], System.Globalization.CultureInfo.InvariantCulture);
                    return new BitLockerVolume((string)v["DeviceID"], v["DriveLetter"] as string ?? (string)v["DeviceID"], protection == 1, conversion == 0);
                }
            }).ToList();
        }
        catch (ManagementException e) when (e.ErrorCode is ManagementStatus.InvalidNamespace or ManagementStatus.InvalidClass) { return null; }
    }

    public void Decrypt(BitLockerVolume volume)
    {
        using var all = Query();
        foreach (var v in all.Cast<ManagementObject>())
            using (v)
                if ((string)v["DeviceID"] == volume.Id) { using var _ = v.InvokeMethod("Decrypt", null, null); }
    }
}

/// <summary>The boot store (Read-AkariBcd, Invoke-AkariBcdEdit): the only bcdedit calls. N7's Safe Mode restarts use it too.</summary>
public interface IBcdEdit
{
    /// <summary>An entry as bcdedit /enum prints it ({current}, {globalsettings}…), errors as text; read only.</summary>
    IReadOnlyList<string> Read(string id);

    /// <summary>A change (/set …, /deletevalue …): bcdedit's exit code.</summary>
    int Run(string arguments);
}

/// <summary>The real one: %SystemRoot%\System32\bcdedit.exe (guarded).</summary>
public sealed class BcdEdit : IBcdEdit
{
    public BcdEdit() => SystemGuard.Check("bcdedit");

    private static string Exe => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "bcdedit.exe");

    public IReadOnlyList<string> Read(string id) =>
        Tool.Lines(Tool.Run(Exe, ["/enum", id]).Output);

    public int Run(string arguments) =>
        Tool.Run(Exe, Tool.Split(arguments)).ExitCode;
}

/// <summary>The only w32tm call (Invoke-AkariW32tm): the Windows Time service started first (w32tm /config needs it),
/// then w32tm; its output lines.</summary>
public interface IW32tm
{
    IReadOnlyList<string> Run(params string[] arguments);
}

/// <summary>The real one: %SystemRoot%\System32\w32tm.exe, W32Time through the service control manager (guarded).</summary>
public sealed class W32tm : IW32tm
{
    private readonly IServiceManager _services;

    public W32tm(IServiceManager services)
    {
        SystemGuard.Check("w32tm");
        _services = services;
    }

    public IReadOnlyList<string> Run(params string[] arguments)
    {
        _services.Start("W32Time");
        return Tool.Lines(Tool.Run(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "w32tm.exe"), arguments).Output);
    }
}

/// <summary>A console tool run and waited for, its output and errors captured.</summary>
internal static class Tool
{
    public static ExeResult Run(string exe, IEnumerable<string> arguments)
    {
        var psi = new ProcessStartInfo(exe) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        foreach (var a in arguments) psi.ArgumentList.Add(a);
        using var p = Process.Start(psi) ?? throw new InvalidOperationException($"{Path.GetFileName(exe)} did not start");
        var err = p.StandardError.ReadToEndAsync();
        var output = p.StandardOutput.ReadToEnd();
        p.WaitForExit();
        return new ExeResult(p.ExitCode, output + err.Result);
    }

    public static IReadOnlyList<string> Lines(string text) =>
        text.Split(["\r\n", "\n"], StringSplitOptions.None).Where(l => l.Length > 0).ToList();

    /// <summary>bcdedit's arguments as one line ('/set {globalsettings} bootuxdisabled on'): split on spaces.</summary>
    public static IReadOnlyList<string> Split(string arguments) =>
        arguments.Split(' ', StringSplitOptions.RemoveEmptyEntries);
}
