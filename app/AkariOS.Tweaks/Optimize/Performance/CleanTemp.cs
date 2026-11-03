using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>src/Tweaks/Optimize/Performance/CleanTemp.ps1: empties the real user's and Windows' temp folders and the
/// Windows Update download cache, deletes the system drive's Windows.old, PerfLogs and crash logs, then runs Disk
/// Cleanup (an Action: deleted files can't be put back). What can't be deleted (in use) stays, as -ErrorAction
/// SilentlyContinue leaves it.</summary>
[TweakCode("performance-clean-temp")]
public sealed class CleanTemp : ITweakCode
{
    public static readonly IReadOnlyList<string> DriveItems = ["DumpStack.log", "Output.txt", "PerfLogs", "Windows.old"];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var s = c.Services;
        var windows = TweakServices.Folder(s.Windows, "Windows");
        var drive = TweakServices.Folder(s.SystemDrive, "system drive");
        if (UserFolders.Get(c.Registry, "Local AppData", s.UserSid) is { } local) Empty(Path.Combine(local, "Temp"), c);
        Empty(Path.Combine(windows, "Temp"), c);
        foreach (var p in DriveItems) Delete(Path.Combine(drive, p), c);
        FileData.Need(s.Services, "service control").Stop("wuauserv");
        Empty(Path.Combine(windows, "SoftwareDistribution"), c);
        FileData.Need(s.Exe, "program runner").Run(Path.Combine(windows, "System32", "cleanmgr.exe"), $"/autoclean /d {drive.TrimEnd('\\')}");
    }

    // a folder's contents, the folder kept
    private static void Empty(string folder, TweakContext c)
    {
        if (!Directory.Exists(folder)) return;
        foreach (var e in Directory.EnumerateFileSystemEntries(folder).ToList()) Delete(e, c);
    }

    private static void Delete(string path, TweakContext c)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
            else if (File.Exists(path)) File.Delete(path);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { c.Log.WriteFile($"Clean: {path} kept ({e.Message})"); }
    }
}
