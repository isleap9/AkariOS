using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/StartupCleanup.ps1: the Run / RunOnce keys emptied (deleted and made again; HKCU the
/// real user's), the two Startup folders emptied, and every scheduled task outside \Microsoft deleted: its task cache
/// key as TrustedInstaller, its task file. An Action: what it removes was put there by other programs.</summary>
[TweakCode("oneclick-startup-cleanup")]
public sealed class StartupCleanup : ITweakCode
{
    public static readonly string[] Keys =
    [
        @"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunNotification", @"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
        @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    ];

    public const string TaskCache = @"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree";

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var k in Keys)
        {
            if (c.Registry.KeyExists(k)) c.Registry.DeleteKey(k);
            c.Registry.CreateKey(k);
        }
        foreach (var d in new[]
                 {
                     Path.Combine(FileData.UserFolder(c, "AppData"), @"Microsoft\Windows\Start Menu\Programs\Startup"),
                     Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), @"Microsoft\Windows\Start Menu\Programs\StartUp"),
                 })
            DeleteChildren(d, keep: null);
        // the task cache is TrustedInstaller's; the task files are the administrators'
        var trusted = TweakServices.Need(c.Services.Trusted, "TrustedInstaller");
        foreach (var k in c.Registry.SubKeys(TaskCache).Where(k => !string.Equals(k, "Microsoft", StringComparison.OrdinalIgnoreCase)))
            trusted.Run(() => c.Registry.DeleteKey($@"{TaskCache}\{k}"));
        DeleteChildren(Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "Tasks"), keep: "Microsoft");
    }

    // Get-ChildItem -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue: what can't go stays
    private static void DeleteChildren(string folder, string? keep)
    {
        if (!Directory.Exists(folder)) return;
        foreach (var e in new DirectoryInfo(folder).EnumerateFileSystemInfos())
        {
            if (keep != null && string.Equals(e.Name, keep, StringComparison.OrdinalIgnoreCase)) continue;
            Apps.Remove.Files.Delete(e.FullName);
        }
    }
}
