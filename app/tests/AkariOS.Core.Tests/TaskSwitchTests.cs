using System.Runtime.InteropServices;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>TaskSwitch (Set-AkariTaskEnabled): through the Task Scheduler as admin, else schtasks as TrustedInstaller
/// (Windows' own tasks refuse an admin); read back, failing when the task stays as it was.</summary>
public sealed class TaskSwitchTests
{
    private sealed class Tasks : ITaskScheduler
    {
        public Dictionary<string, bool> On { get; } = [];
        public HashSet<string> Refuse { get; } = [];
        public List<string> Calls { get; } = [];
        public IReadOnlyList<ScheduledTask> Find(Func<string, bool> name) => [];
        public bool Unregister(ScheduledTask task) => true;

        public void SetEnabled(ScheduledTask task, bool enabled)
        {
            Calls.Add($"set {task.Folder}|{task.Name}|{enabled}");
            if (Refuse.Contains(task.Name)) throw new COMException("Access is denied", unchecked((int)0x80070005));
            if (!On.ContainsKey(task.Name)) throw new COMException("The system cannot find the file specified", unchecked((int)0x80070002));
            On[task.Name] = enabled;
        }

        public TaskInfo? One(string path, string name) =>
            On.TryGetValue(name, out var on) ? new TaskInfo(path, name, on, on ? "Ready" : "Disabled", "", "") : null;
    }

    private sealed class Trusted(Tasks tasks, bool works) : ITrustedInstaller
    {
        public List<string> Started { get; } = [];
        public void Run(Action work) => work();

        public int Start(string exe, string arguments)
        {
            Started.Add($"{Path.GetFileName(exe)} {arguments}");
            if (works) tasks.On["Schedule Scan"] = arguments.EndsWith("/enable", StringComparison.Ordinal);
            return 0;
        }
    }

    private const string Orchestrator = @"\Microsoft\Windows\UpdateOrchestrator\";

    [Fact]
    public void An_admin_change_goes_through_the_task_scheduler()
    {
        var tasks = new Tasks { On = { ["MapsUpdateTask"] = true } };
        TaskSwitch.Set(tasks, null, @"C:\Windows", @"\Microsoft\Windows\Maps\", "MapsUpdateTask", false);
        Assert.Equal([@"set \Microsoft\Windows\Maps|MapsUpdateTask|False"], tasks.Calls);
        Assert.False(tasks.On["MapsUpdateTask"]);
    }

    [Fact]
    public void A_refused_one_goes_through_schtasks_as_trustedinstaller()
    {
        var tasks = new Tasks { On = { ["Schedule Scan"] = true }, Refuse = { "Schedule Scan" } };
        var trusted = new Trusted(tasks, works: true);
        TaskSwitch.Set(tasks, trusted, @"C:\Windows", Orchestrator, "Schedule Scan", false);
        Assert.Equal([$"schtasks.exe /change /tn \"{Orchestrator}Schedule Scan\" /disable"], trusted.Started);
        Assert.False(tasks.On["Schedule Scan"]);
    }

    [Fact]
    public void A_task_windows_keeps_fails()
    {
        var tasks = new Tasks { On = { ["Schedule Scan"] = true }, Refuse = { "Schedule Scan" } };
        var e = Assert.Throws<InvalidOperationException>(() => TaskSwitch.Set(tasks, new Trusted(tasks, works: false), @"C:\Windows", Orchestrator, "Schedule Scan", false));
        Assert.Equal("Windows keeps this task on", e.Message);
        var gone = Assert.Throws<InvalidOperationException>(() => TaskSwitch.Set(tasks, new Trusted(tasks, works: false), @"C:\Windows", Orchestrator, "Gone", true));
        Assert.Equal($"no task {Orchestrator}Gone", gone.Message);
    }

    [Theory]
    [InlineData(@"\Microsoft\Windows\Maps\", @"\Microsoft\Windows\Maps")]
    [InlineData(@"\", @"\")]
    public void A_task_path_is_its_com_folder(string path, string folder) => Assert.Equal(folder, Machine.TaskScheduler.FolderOf(path));
}
