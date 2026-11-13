using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Features;

/// <summary>src/Tweaks/Advanced/Features/RegistryBackup.ps1 (winutil's RegBackup): EnablePeriodicBackup = 1 and
/// BackupCount = 2, and Akari's daily task running RegIdleBackup (AkariOS turns automatic maintenance off). Revert removes
/// both values and the task.</summary>
[TweakCode("features-registry-backup")]
public sealed class RegistryBackup : ITweakCode
{
    private const string Key = @"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager";
    private const string TaskPath = @"\AkariOS\";
    private const string TaskName = "RegistryBackup";

    private static ITaskScheduler Tasks(TweakContext c) => TweakServices.Need(c.Services.Tasks, "task scheduler");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var on = c.Registry.GetValue(Key, "EnablePeriodicBackup");
        var count = c.Registry.GetValue(Key, "BackupCount");
        var task = Tasks(c).One(TaskPath, TaskName) is not null;
        if (RegistryEngine.Matches(on, 1) && RegistryEngine.Matches(count, 2) && task) return TweakState.Optimized;
        return on is null && count is null && !task ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        c.Registry.SetValue(Key, "EnablePeriodicBackup", 1, "DWord");
        c.Registry.SetValue(Key, "BackupCount", 2, "DWord");
        Tasks(c).RegisterDaily(TaskPath, TaskName, "schtasks.exe", @"/run /i /tn ""\Microsoft\Windows\Registry\RegIdleBackup""", "00:30",
            "Backs up the registry every day (AkariOS)");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        c.Registry.RemoveValue(Key, "EnablePeriodicBackup");
        c.Registry.RemoveValue(Key, "BackupCount");
        Tasks(c).Unregister(new ScheduledTask(Core.Machine.TaskScheduler.FolderOf(TaskPath), TaskName));
    }
}
