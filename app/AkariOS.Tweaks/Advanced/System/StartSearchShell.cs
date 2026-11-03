using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Customize.Apps;

namespace AkariOS.Tweaks.Advanced.SystemTweaks;

/// <summary>
/// src/Tweaks/Advanced/System/StartSearchShell.ps1: the Search, Shell Experience and Start menu app folders and
/// mobsync.exe moved into %SystemRoot% (taken over first, the hosts stopped right before each move, five tries), Search
/// turned off by policy and its service disabled; Revert moves them back and turns Search on. The folder names, the
/// moves and the programs to stop are read out of the file.
/// </summary>
[TweakCode("system-start-search-shell-off")]
public sealed partial class StartSearchShell : ITweakCode
{
    [GeneratedRegex(@"@\(""\$env:SystemRoot\\(?<from>[^""]+)"",\s*""\$env:SystemRoot\\(?<to>[^""]+)""\)")]
    private static partial Regex Move();

    private const string PolicyManager = @"HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Search\DisableSearch";
    private const string Policy = @"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";
    private const string WSearch = @"HKLM:\SYSTEM\CurrentControlSet\Services\WSearch";

    private static string Root(TweakContext c) => TweakServices.Folder(c.Services.Windows, "Windows");

    /// <summary>A block's moves, as paths under %SystemRoot% (from, to).</summary>
    public static IReadOnlyList<(string From, string To)> Moves(Tweak t, string block) =>
        Move().Matches(AppHive.Block(t, block)).Select(m => (m.Groups["from"].Value, m.Groups["to"].Value)).ToList();

    private static bool Exists(string p) => File.Exists(p) || Directory.Exists(p);

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var root = Root(c);
        var names = FileData.AssignedList(c.Files, tweak.Source, "names");
        var moved = names.Count(n => Exists(Path.Combine(root, n))) + (Exists(Path.Combine(root, "mobsync.exe")) ? 1 : 0);
        var inPlace = names.Count(n => Exists(Path.Combine(root, "SystemApps", n))) + (Exists(Path.Combine(root, "System32", "mobsync.exe")) ? 1 : 0);
        if (moved > 0 && inPlace == 0) return TweakState.Optimized;
        return inPlace > 0 && moved == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var root = Root(c);
        var s = c.Services;
        var stop = FileData.AssignedList(c.Files, tweak.Source, "stop");
        var processes = FileData.Need(s.Processes, "process control");
        var moves = Moves(tweak, "Apply").Select(m => (From: Path.Combine(root, m.From), To: Path.Combine(root, m.To))).ToList();
        foreach (var m in moves) SystemFiles.GrantOwnership(c, m.From);
        // the hosts start again on their own: stop them right before each move, a few tries
        foreach (var m in moves)
        {
            for (var t = 0; t < 5 && Exists(m.From) && !Exists(m.To); t++)
            {
                foreach (var p in stop) processes.Stop(p);
                try { SystemFiles.Move(m.From, m.To); }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
                if (Exists(m.From)) s.Sleep(TimeSpan.FromMilliseconds(500));
            }
            if (Exists(m.From)) throw new InvalidOperationException($"could not move {m.From} (in use)");
        }
        c.Registry.SetValue(PolicyManager, "value", 1, "DWord");
        c.Registry.SetValue(Policy, "DisableSearch", 1, "DWord");
        c.Registry.SetValue(WSearch, "Start", 4, "DWord");
        FileData.Need(s.Services, "service control").Stop("WSearch");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var root = Root(c);
        foreach (var (from, to) in Moves(tweak, "Revert").Select(m => (Path.Combine(root, m.From), Path.Combine(root, m.To))))
        {
            if (!Exists(from) || Exists(to)) continue;
            SystemFiles.GrantOwnership(c, from);
            SystemFiles.Move(from, to);
        }
        c.Registry.SetValue(PolicyManager, "value", 0, "DWord");
        c.Registry.RemoveValue(Policy, "DisableSearch");
        c.Registry.SetValue(WSearch, "Start", 2, "DWord");
        FileData.Need(c.Services.Services, "service control").Start("WSearch");
    }
}

/// <summary>System files a Tweak takes over or moves (Grant-AkariOwnership, Move-Item).</summary>
public static class SystemFiles
{
    /// <summary>takeown + icacls for the Administrators group, everything inside too; a missing path is nothing to do.</summary>
    public static void GrantOwnership(TweakContext c, string path)
    {
        if (!File.Exists(path) && !Directory.Exists(path)) return;
        var system32 = Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32");
        var exe = FileData.Need(c.Services.Exe, "program runner");
        exe.Run(Path.Combine(system32, "takeown.exe"), $"/f \"{path}\" /a /r /d y");
        exe.Run(Path.Combine(system32, "icacls.exe"), $"\"{path}\" /grant *S-1-5-32-544:F /t /q");
    }

    /// <summary>A folder or a file moved (Move-Item -Force: a file there is replaced).</summary>
    public static void Move(string from, string to)
    {
        if (Directory.Exists(from)) Directory.Move(from, to);
        else File.Move(from, to, overwrite: true);
    }
}
