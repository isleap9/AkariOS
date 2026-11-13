using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Fixes;

/// <summary>
/// src/Tweaks/Tools/Fixes/SystemRepair.ps1 (winutil's Invoke-WPFSystemRepair): chkdsk /scan /perf, sfc /scannow, DISM
/// /Online /Cleanup-Image /RestoreHealth, each waited for. A nonzero exit code its step accepts (chkdsk 1 and 2, DISM
/// 3010) is logged with its meaning; any other stops the scan, and the Action fails with it.
/// </summary>
[TweakCode("tools-system-repair")]
public sealed class SystemRepair : ITweakCode
{
    public sealed record Step(string Label, string Exe, string[] Arguments, IReadOnlyDictionary<int, string> Ok);

    public static readonly IReadOnlyList<Step> Steps =
    [
        new("Checking the disk for errors", "chkdsk.exe", ["/scan", "/perf"],
            new Dictionary<int, string> { [1] = "errors were found and fixed", [2] = "cleanup was done, or skipped without /f" }),
        new("Scanning protected system files", "sfc.exe", ["/scannow"], new Dictionary<int, string>()),
        new("Repairing the Windows image", "dism.exe", ["/Online", "/Cleanup-Image", "/RestoreHealth"],
            new Dictionary<int, string> { [3010] = "restart Windows for the repair to take effect" }),
    ];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var sys = Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32");
        var exe = TweakServices.Need(c.Services.Exe, "program runner");
        var n = 0;
        foreach (var s in Steps)
        {
            n++;
            c.Log.Write($"System repair ({n} of {Steps.Count}): {s.Label}");
            var code = exe.Run(Path.Combine(sys, s.Exe), ExeArgs.Join(s.Arguments)).ExitCode;
            if (code == 0) continue;
            if (s.Ok.TryGetValue(code, out var meaning)) { c.Log.Write($"System repair: {s.Label} finished: {meaning}"); continue; }
            throw new InvalidOperationException($"{s.Label} failed (exit code {code})");
        }
        c.Log.Write("System repair: done");
    }
}
