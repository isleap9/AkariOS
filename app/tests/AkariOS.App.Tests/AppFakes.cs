using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Tests;

/// <summary>The PC's Store packages for the App tests: removable ones by name, each with an optional logo folder.</summary>
internal sealed class FakePackages : IPackageManager
{
    public List<AppPackage> Packages { get; } = [];
    public List<string> Calls { get; } = [];
    public int Reads { get; private set; }

    public FakePackages Add(params string[] names)
    {
        foreach (var n in names) Packages.Add(new AppPackage(n, $"{n}_1.0.0.0_x64__8wekyb3d8bbwe", $"{n}_8wekyb3d8bbwe", null, false, false, false, false));
        return this;
    }

    public IReadOnlyList<AppPackage> AllUsers() { Reads++; return Packages.ToList(); }
    public void Remove(string fullName) { Calls.Add($"remove {fullName}"); Packages.RemoveAll(p => p.FullName == fullName); }
    public void RegisterByFamily(string family) => Calls.Add($"register-family {family}");
    public void Register(string manifest) => Calls.Add($"register {manifest}");
    public void Add(string file) => Calls.Add($"add {file}");
    public IReadOnlyList<ProvisionedApp> ProvisionedApps() => [];
    public void Deprovision(string family) => Calls.Add($"deprovision {family}");
}

/// <summary>winget.exe for the App tests: every call recorded, "--version" 1.9.0, the rest code 0 with no lines unless
/// Answer says otherwise (null = that default). Nothing real is run.</summary>
internal sealed class FakeWinget : IWinget
{
    public List<string> Calls { get; } = [];
    public Func<string[], WingetResult?>? Answer { get; set; }

    public WingetResult Run(params string[] arguments)
    {
        Calls.Add(string.Join(" ", arguments));
        return Answer?.Invoke(arguments) ?? (arguments[0] == "--version" ? new(0, ["v1.9.0"]) : new(0, []));
    }
}

/// <summary>No downloads in the App tests (winget's own repair never runs: the fake winget is recent).</summary>
internal sealed class NoDownloads : Core.Update.IHttp
{
    public void Download(string url, string file) => throw new InvalidOperationException("no downloads in tests");
}

/// <summary>The PC's services for the Services page: All / One answer List; Control records and updates the status.</summary>
internal sealed class FakeServiceManager : IServiceManager
{
    public List<ServiceInfo> List { get; } = [];
    public List<string> Calls { get; } = [];
    public int Reads { get; private set; }

    public IReadOnlyList<ServiceInfo> All() { Reads++; return List.ToList(); }
    public ServiceInfo? One(string name) => List.FirstOrDefault(s => s.Name == name);

    public void Control(string name, string op)
    {
        Calls.Add($"{op} {name}");
        var i = List.FindIndex(s => s.Name == name);
        List[i] = List[i] with { Status = op == "Start" ? "Running" : "Stopped" };
    }

    public string? StartType(string name) => One(name)?.Start;
    public bool Stop(string name) => true;
    public bool Start(string name) => true;
    public void Create(string name, string binaryPath, bool automatic) { }
    public void Delete(string name) { }
    public IReadOnlyList<string> Names() => List.Select(s => s.Name).ToList();
}

/// <summary>The PC's scheduled tasks for the Scheduled tasks page; SetEnabled records and updates; Refuse = names an
/// admin can't change (COMException), so the TrustedInstaller fallback runs.</summary>
internal sealed class FakeTaskScheduler : ITaskScheduler
{
    public List<TaskInfo> List { get; } = [];
    public List<string> Calls { get; } = [];
    public HashSet<string> Refuse { get; } = [];

    public IReadOnlyList<TaskInfo> All() => List.ToList();
    public TaskInfo? One(string path, string name) => List.FirstOrDefault(t => t.Path == path && t.Name == name);
    public IReadOnlyList<ScheduledTask> Find(Func<string, bool> name) => [];
    public bool Unregister(ScheduledTask task) => true;

    public void SetEnabled(ScheduledTask task, bool enabled)
    {
        if (Refuse.Contains(task.Name)) throw new System.Runtime.InteropServices.COMException("Access is denied");
        Calls.Add($"{task.Folder}|{task.Name}|{enabled}");
        Set(task.Name, enabled);
    }

    public void Set(string name, bool enabled)
    {
        var i = List.FindIndex(t => t.Name == name);
        List[i] = List[i] with { Enabled = enabled, State = enabled ? "Ready" : "Disabled" };
    }
}

/// <summary>TrustedInstaller for the App tests: runs registry work as is; Start records the program (Started) and, for
/// schtasks, does what it asks on the fake tasks.</summary>
internal sealed class FakeTrustedInstaller(FakeTaskScheduler tasks) : ITrustedInstaller
{
    public List<string> Started { get; } = [];
    public void Run(Action work) => work();

    public int Start(string exe, string arguments)
    {
        Started.Add($"{System.IO.Path.GetFileName(exe)} {arguments}");
        var name = arguments.Split('"')[1].Split('\\')[^1];
        tasks.Set(name, arguments.EndsWith("/enable", StringComparison.Ordinal));
        return 0;
    }
}

/// <summary>The PC's Optional and Windows features; Reads counts the list reads (the Remove tab's background read).</summary>
internal sealed class FakeDism : IDism
{
    public List<DismItem> Capabilities { get; } = [];
    public List<DismItem> Features { get; } = [];
    public int Reads { get; private set; }

    IReadOnlyList<DismItem> IDism.Capabilities() { Reads++; return Capabilities.ToList(); }
    IReadOnlyList<DismItem> IDism.Features() { Reads++; return Features.ToList(); }
    public string? CapabilityState(string name) => Capabilities.FirstOrDefault(c => c.Name == name)?.State;
    public string? FeatureState(string name) => Features.FirstOrDefault(f => f.Name == name)?.State;
    public void RemoveCapability(string name) { }
    public void DisableFeature(string name) { }
}
