using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Customize.Apps;

namespace AkariOS.Tweaks.Advanced.Security;

/// <summary>src/Tweaks/Advanced/Security/DefenderTasks.ps1's After, both ways: Defender's scheduled tasks (the
/// file's list, read out of its block) off on Apply, on on Revert (Set-AkariScheduledTask: a task this PC doesn't have
/// is skipped). Its Registry rows are the engine's.</summary>
[TweakCode("security-defender-tasks-off")]
public sealed partial class DefenderTasks : ITweakCode
{
    [GeneratedRegex(@"@\('(?<folder>[^']*)',\s*'(?<name>[^']*)'\)")]
    private static partial Regex TaskPair();

    /// <summary>The (folder, name) pairs the After block lists.</summary>
    public static IReadOnlyList<(string Folder, string Name)> Tasks(Tweak t) =>
        TaskPair().Matches(AppHive.Block(t, "After")).Select(m => (m.Groups["folder"].Value, m.Groups["name"].Value)).ToList();

    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var scheduler = FileData.Need(c.Services.Tasks, "Task Scheduler");
        foreach (var (folder, name) in Tasks(tweak))
            foreach (var task in scheduler.Find(n => n.Equals(name, StringComparison.OrdinalIgnoreCase)).Where(t => SameFolder(t.Folder, folder)))
                scheduler.SetEnabled(task, mode != TweakMode.Apply);
    }

    // "\Microsoft\Windows\Windows Defender\" as Get-ScheduledTask -TaskPath writes it, "\Microsoft\Windows\Windows
    // Defender" as the Task Scheduler's folder path is
    private static bool SameFolder(string a, string b) => a.TrimEnd('\\').Equals(b.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase);
}
