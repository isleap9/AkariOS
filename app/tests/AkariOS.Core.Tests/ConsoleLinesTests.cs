using System.Text.Json;
using AkariOS.Core.Runs;

namespace AkariOS.Core.Tests;

/// <summary>The console's look: every kind of log line formatted as src\Core\Log.ps1's ConvertTo-AkariConsoleLine does
/// (Oracle/Export-ConsoleLines.ps1), segment for segment and colour for colour.</summary>
public sealed class ConsoleLinesTests
{
    private static readonly string[] Lines =
    [
        "Phase 2 of 5: Safe Mode", "Phase 10 of 12: A very long phase name that goes past the rule's width on its own",
        "Applied: Game DVR off", "Reverted: Rows (as it was before the Run)", "Reverted: Plain", "Already: Game DVR off",
        "Skipped: Hyper-V (needs Pro)", "Skipped: Plain", "Failed: Defender: access denied: really", "Failed: Unknown",
        "In Safe Mode: Defender off", "Warning: preset x: 'y' is not a Tweak here", "Error: something", "Restarting into Safe Mode for: Safe Mode",
        "Stopped in Safe Mode: a change failed", "Done: 12 applied, 3 already", "Done: 2 applied, 1 failed", "  Failed: tog: denied",
        "Reading the apps and features on this PC...", "applied: lower case", "  trailing spaces   ",
    ];

    [Fact]
    public void Lines_are_powershells()
    {
        var cases = Path.Combine(Path.GetTempPath(), $"akari-console-{Guid.NewGuid():N}.json");
        File.WriteAllText(cases, JsonSerializer.Serialize(Lines));
        try
        {
            var ps = Oracle.Run("Export-ConsoleLines.ps1", "-Src", Repo.Src, "-Cases", cases).EnumerateArray().Select(e => e.GetString() ?? "").ToList();
            Assert.Equal(ps, Lines.Select(l => string.Join("\t", ConsoleLines.Format(l, "12:03:44").Select(s => $"{s.Text}|{s.Color}"))).ToList());
        }
        finally { File.Delete(cases); }
        Assert.Equal("AkariOS · phase 2 of 5 · Safe Mode", ConsoleLines.Title("Phase 2 of 5: Safe Mode"));
        Assert.Null(ConsoleLines.Title("Applied: x"));
    }
}
