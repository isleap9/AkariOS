using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Start;

/// <summary>src/Tweaks/Customize/Start/AkariOSShortcuts.ps1: Recycle Bin, both Start menu folders and both Startup
/// folders as shortcuts in All apps (an Action: Akari leaves them for the user to keep or delete). Done = the last one
/// is there.</summary>
[TweakCode("start-akarios-shortcuts")]
public sealed class AkariOSShortcuts : ITweakCode
{
    private static string Programs(TweakContext c) =>
        Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), @"Microsoft\Windows\Start Menu\Programs");

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        File.Exists(Path.Combine(Programs(c), "Startup Programs 2.lnk")) ? TweakState.Optimized : TweakState.Default;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var programs = Programs(c);
        var mine = FileData.UserFolder(c, "Programs");
        var links = new (string Name, string Target)[]
        {
            ("Start Menu Shortcuts 1", programs),
            ("Start Menu Shortcuts 2", mine),
            ("Startup Programs 1", Path.Combine(mine, "Startup")),
            ("Startup Programs 2", Path.Combine(programs, "StartUp")),
            ("Recycle Bin", "::{645ff040-5081-101b-9f08-00aa002f954e}"),
        };
        var shortcuts = FileData.Need(c.Services.Shortcuts, "shortcuts");
        foreach (var (name, target) in links) shortcuts.Create(Path.Combine(programs, $"{name}.lnk"), target);
    }
}
