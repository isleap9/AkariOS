using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/OneDrive.ps1: OneDrive for every user (Windows' OneDriveSetup -uninstall, then the
/// Microsoft 365 / per-machine copy's own setup /uninstall /allusers) and its scheduled tasks. An Action: OneDrive
/// comes back by running its setup again. Done = no OneDrive.exe in the user's or the machine's folders.</summary>
[TweakCode("remove-onedrive")]
public sealed class OneDrive : ITweakCode
{
    private static IEnumerable<string> Folders(TweakContext c)
    {
        yield return Path.Combine(TweakServices.Folder(c.Services.ProgramFiles, "Program Files"), "Microsoft OneDrive");
        yield return Path.Combine(TweakServices.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"), "Microsoft OneDrive");
        yield return Path.Combine(FileData.UserFolder(c, "Local AppData"), "Microsoft", "OneDrive");
    }

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var local = Path.Combine(FileData.UserFolder(c, "Local AppData"), "Microsoft", "OneDrive", "OneDrive.exe");
        var there = File.Exists(local) || Folders(c).Take(2).Any(f => File.Exists(Path.Combine(f, "OneDrive.exe")));
        return there ? TweakState.Default : TweakState.Optimized;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        FileData.Need(c.Services.Processes, "process list").Stop("OneDrive");
        var exe = FileData.Need(c.Services.Exe, "program runner");
        var windows = TweakServices.Folder(c.Services.Windows, "Windows");
        foreach (var setup in new[] { Path.Combine(windows, "System32", "OneDriveSetup.exe"), Path.Combine(windows, "SysWOW64", "OneDriveSetup.exe") })
            if (File.Exists(setup)) exe.Run(setup, "-uninstall");
        // the Microsoft 365 / per-machine copy
        foreach (var folder in Folders(c).Where(Directory.Exists))
            foreach (var setup in Directory.GetFiles(folder, "OneDriveSetup.exe", SearchOption.AllDirectories))
                exe.Run(setup, "/uninstall /allusers");
        Tasks.Unregister(c, n => Regex.IsMatch(n, "OneDrive", RegexOptions.IgnoreCase));
    }
}
