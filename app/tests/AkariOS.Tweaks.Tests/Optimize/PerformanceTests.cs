using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tests.Optimize;

/// <summary>Optimize › Performance's script-block Tweaks (g2) on a test key, temp folders and fakes.</summary>
public sealed class PerformanceTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    [Fact]
    public void Every_performance_tweak_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Optimize" && t.Category == "Performance"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    [Fact]
    public void Memory_compression_goes_off_and_back_on()
    {
        Assert.Equal(TweakState.Default, _h.State("disable-memory-compression"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("disable-memory-compression", TweakMode.Apply).Kind);
        Assert.Equal((false, TweakState.Optimized), (_h.Memory.MemoryCompression, _h.State("disable-memory-compression")));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("disable-memory-compression", TweakMode.Revert).Kind);
        Assert.True(_h.Memory.MemoryCompression);
    }

    [Fact]
    public void Bitlocker_decrypts_what_is_left_and_is_done_without_bitlocker()
    {
        _h.BitLocker.All = [new("a", "C:", true, false), new("b", "D:", false, true), new("c", "E:", false, false)];
        Assert.Equal(OutcomeKind.Applied, _h.Run("performance-bitlocker-off", TweakMode.Apply).Kind);
        Assert.Equal(["C:", "E:"], _h.BitLocker.Decrypting);
        Assert.Contains("Decrypting C:", _h.Log.Lines);
        _h.BitLocker.All = [new("b", "D:", false, true)];
        Assert.Equal(OutcomeKind.Already, _h.Run("performance-bitlocker-off", TweakMode.Apply).Kind);
        _h.BitLocker.All = null;
        Assert.Equal(OutcomeKind.Already, _h.Run("performance-bitlocker-off", TweakMode.Apply).Kind);
    }

    [Fact]
    public void Clean_temp_empties_the_real_users_and_windows_folders_and_runs_disk_cleanup()
    {
        var user = _h.Folder(@"User\AppData\Local");
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", "Local AppData", user, "String");
        var windows = _h.Engine.Services.Windows;
        var drive = _h.Engine.Services.SystemDrive;
        foreach (var f in new[] { @"User\AppData\Local\Temp\a.tmp", @"User\AppData\Local\Temp\sub\b.tmp", @"Windows\Temp\c.tmp", @"Windows\SoftwareDistribution\Download\d.cab",
                     @"C\Windows.old\x", @"C\PerfLogs\y", @"C\DumpStack.log", @"C\keep.txt" })
        {
            var p = Path.Combine(_h.Dir, f);
            Directory.CreateDirectory(Path.GetDirectoryName(p)!);
            File.WriteAllText(p, "");
        }
        Assert.Equal(OutcomeKind.Applied, _h.Run("performance-clean-temp", TweakMode.Apply).Kind);
        Assert.Empty(Directory.EnumerateFileSystemEntries(Path.Combine(user, "Temp")));
        Assert.Empty(Directory.EnumerateFileSystemEntries(Path.Combine(windows, "Temp")));
        Assert.Empty(Directory.EnumerateFileSystemEntries(Path.Combine(windows, "SoftwareDistribution")));
        Assert.Equal(["keep.txt"], Directory.EnumerateFileSystemEntries(drive).Select(Path.GetFileName));
        Assert.Equal(["stop wuauserv"], _h.Services.Calls);
        Assert.Equal([$"cleanmgr.exe /autoclean /d {drive.TrimEnd('\\')}"], _h.Exe.Runs);
    }

    [Fact]
    public void The_defrag_schedule_turns_its_task_off_and_on_with_its_values()
    {
        var defrag = new ScheduledTask(@"\Microsoft\Windows\Defrag", "ScheduledDefrag");
        var other = new ScheduledTask(@"\Microsoft\Windows\Other", "Other");
        _h.Tasks.All[defrag] = true;
        _h.Tasks.All[other] = true;
        Assert.Equal(OutcomeKind.Applied, _h.Run("performance-defrag-schedule-off", TweakMode.Apply).Kind);
        Assert.Equal((false, true), (_h.Tasks.All[defrag], _h.Tasks.All[other]));
        Assert.Equal(0u, _h.Get(@"HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings", "fTaskEnabled"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("performance-defrag-schedule-off", TweakMode.Revert).Kind);
        Assert.True(_h.Tasks.All[defrag]);
    }

    [Fact]
    public void The_startup_pages_open()
    {
        _h.Run("performance-open-startup-apps", TweakMode.Apply);
        _h.Run("performance-open-startup-taskmgr", TweakMode.Apply);
        Assert.Equal(["ms-settings:startupapps"], _h.Launcher.Opened);
        Assert.Equal(["taskmgr.exe /0 /startup"], _h.Exe.Runs);
    }

    [Fact]
    public void The_timer_resolution_service_is_compiled_installed_and_removed()
    {
        const string service = "Set Timer Resolution Service";
        var exe = Path.Combine(_h.Engine.Services.Windows, "SetTimerResolutionService.exe");
        // csc writes the exe it is asked for
        _h.Exe.Result = (path, args) =>
        {
            File.WriteAllText(exe, "MZ");
            return new ExeResult(0, "");
        };
        Assert.Equal(TweakState.Default, _h.State("performance-timer-resolution"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("performance-timer-resolution", TweakMode.Apply).Kind);
        Assert.Equal(TweakState.Optimized, _h.State("performance-timer-resolution"));
        Assert.Equal([$"create {service} {exe}", $"start {service}"], _h.Services.Calls);
        Assert.StartsWith("csc.exe -nologo \"-out:", _h.Exe.Runs[0]);
        // the source as src/OneClick has it, written out to the Files folder for csc
        Assert.Equal(File.ReadAllText(Path.Combine(Core.Tests.Repo.Src, "OneClick", "settimerresolutionservice.cs")),
            File.ReadAllText(Path.Combine(_h.Engine.Services.FilesFolder, "settimerresolutionservice.cs")));
        Assert.Equal(1u, _h.Get(@"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", "GlobalTimerResolutionRequests"));

        // applied again: Already; one left set to Manual (Custom) is removed first, then made again
        Assert.Equal(OutcomeKind.Already, _h.Run("performance-timer-resolution", TweakMode.Apply).Kind);
        _h.Services.Installed[service] = "Manual";
        Assert.Equal(TweakState.Custom, _h.State("performance-timer-resolution"));
        _h.Run("performance-timer-resolution", TweakMode.Apply);
        Assert.Equal([$"stop {service}", $"delete {service}", $"create {service} {exe}"], _h.Services.Calls.Skip(2).Take(3));

        Assert.Equal(OutcomeKind.Reverted, _h.Run("performance-timer-resolution", TweakMode.Revert).Kind);
        Assert.Equal((TweakState.Default, false), (_h.State("performance-timer-resolution"), File.Exists(exe)));
        Assert.Null(_h.Get(@"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel", "GlobalTimerResolutionRequests"));

        // csc failing: Failed, no service
        _h.Exe.Result = (_, _) => new ExeResult(1, "error CS1002");
        var o = _h.Run("performance-timer-resolution", TweakMode.Apply);
        Assert.Equal((OutcomeKind.Failed, (string?)null), (o.Kind, _h.Services.StartType(service)));
        Assert.Contains("csc failed: error CS1002", o.Message);
    }

    [Fact]
    public void Write_cache_flushing_goes_off_on_every_disk_and_revert_leaves_other_values()
    {
        const string e = @"HKLM:\SYSTEM\ControlSet001\Enum";
        Assert.Equal(TweakState.Unknown, _h.State("performance-write-cache-flushing-off"));
        _h.Set($@"{e}\SCSI\Disk&Ven_A\1\Device Parameters", "x", 1, "DWord");
        _h.Set($@"{e}\NVME\Disk&Ven_B\2\Device Parameters\Disk", "UserWriteCacheSetting", 1, "DWord");
        Assert.Equal(TweakState.Default, _h.State("performance-write-cache-flushing-off"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("performance-write-cache-flushing-off", TweakMode.Apply).Kind);
        Assert.Equal(1u, _h.Get($@"{e}\SCSI\Disk&Ven_A\1\Device Parameters\Disk", "CacheIsPowerProtected"));
        Assert.Equal(TweakState.Optimized, _h.State("performance-write-cache-flushing-off"));
        _h.Engine.Registry.RemoveValue($@"{e}\SCSI\Disk&Ven_A\1\Device Parameters\Disk", "CacheIsPowerProtected");
        Assert.Equal(TweakState.Custom, _h.State("performance-write-cache-flushing-off"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("performance-write-cache-flushing-off", TweakMode.Revert).Kind);
        Assert.Equal(TweakState.Default, _h.State("performance-write-cache-flushing-off"));
        Assert.Equal(1u, _h.Get($@"{e}\NVME\Disk&Ven_B\2\Device Parameters\Disk", "UserWriteCacheSetting"));
    }

    [Fact]
    public void The_real_users_folder_comes_from_their_shell_folders_else_their_profile()
    {
        Assert.Null(UserFolders.Get(_h.Engine.Registry, "Local AppData"));
        _h.Set(@"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-9", "ProfileImagePath", @"D:\Users\me", "String");
        Assert.Equal(@"D:\Users\me\AppData\Local", UserFolders.Get(_h.Engine.Registry, "Local AppData", "S-1-5-21-9"));
        Assert.Equal(@"D:\Users\me\Desktop", UserFolders.Get(_h.Engine.Registry, "Desktop", "S-1-5-21-9"));
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", "{374DE290-123F-4565-9164-39C4925E467B}", @"E:\Dl", "String");
        Assert.Equal(@"E:\Dl", UserFolders.Get(_h.Engine.Registry, "Downloads", "S-1-5-21-9"));
    }
}
