using System.Runtime.InteropServices;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Machine;

/// <summary>
/// Set-AkariTaskEnabled: a scheduled task turned on or off through the Task Scheduler as admin, else with schtasks run
/// as TrustedInstaller (Windows' own tasks, such as UpdateOrchestrator's, refuse an admin); read back after, failing
/// when it stays as it was.
/// </summary>
public static class TaskSwitch
{
    /// <summary>path: the task's folder with a trailing \ (TaskInfo.Path); windows: %SystemRoot% (schtasks.exe).</summary>
    public static void Set(ITaskScheduler tasks, ITrustedInstaller? trusted, string windows, string path, string name, bool enabled)
    {
        try { tasks.SetEnabled(new ScheduledTask(TaskScheduler.FolderOf(path), name), enabled); }
        catch (Exception e) when (e is COMException or UnauthorizedAccessException)
        {
            if (trusted is null) throw;
            trusted.Start(Path.Combine(windows, "System32", "schtasks.exe"), $"/change /tn \"{path}{name}\" {(enabled ? "/enable" : "/disable")}");
        }
        var now = tasks.One(path, name) ?? throw new InvalidOperationException($"no task {path}{name}");
        if (now.Enabled != enabled) throw new InvalidOperationException($"Windows keeps this task {(enabled ? "off" : "on")}");
    }
}
