using System.Text.RegularExpressions;

namespace AkariOS.Core.Runs;

/// <summary>
/// The console's look (src/Core/Log.ps1's ConvertTo-AkariConsoleLine): each log line with a time column and a
/// fixed-width status tag in its colour, a phase as a ruled header, the Run's "Done:" line as a finish block. Pure;
/// matching ignores case, as PowerShell's -match;
/// ConsoleLinesTests compares it with the PowerShell app's.
/// </summary>
public static partial class ConsoleLines
{
    public const char Rule = '─';
    public const int Width = 72;

    /// <summary>One printed piece; an empty Text is a line break.</summary>
    public sealed record Segment(string Text, ConsoleColor Color);

    [GeneratedRegex(@"^Phase (\d+) of (\d+): (.+)$", RegexOptions.IgnoreCase)] private static partial Regex PhaseRx();
    [GeneratedRegex(@"^Done: (.+)$", RegexOptions.IgnoreCase)] private static partial Regex DoneRx();
    [GeneratedRegex(@"^  Failed: (.+?): (.*)$", RegexOptions.IgnoreCase)] private static partial Regex SummaryFailRx();
    [GeneratedRegex(@"^Applied: (.+)$", RegexOptions.IgnoreCase)] private static partial Regex AppliedRx();
    [GeneratedRegex(@"^Reverted: (.+?)( \((.+)\))?$", RegexOptions.IgnoreCase)] private static partial Regex RevertedRx();
    [GeneratedRegex(@"^Already: (.+)$", RegexOptions.IgnoreCase)] private static partial Regex AlreadyRx();
    [GeneratedRegex(@"^Skipped: (.+?)( \((.+)\))?$", RegexOptions.IgnoreCase)] private static partial Regex SkippedRx();
    [GeneratedRegex(@"^Failed: (.+?)(: (.+))?$", RegexOptions.IgnoreCase)] private static partial Regex FailedRx();
    [GeneratedRegex(@"^In Safe Mode: (.+)$", RegexOptions.IgnoreCase)] private static partial Regex SafeRx();
    [GeneratedRegex(@"^(Warning|Error): (.+)$", RegexOptions.IgnoreCase)] private static partial Regex WarnRx();
    [GeneratedRegex(@"^(Restarting|Stopped) ", RegexOptions.IgnoreCase)] private static partial Regex RestartRx();

    /// <summary>The window title for a phase line, or null.</summary>
    public static string? Title(string message) =>
        PhaseRx().Match(message.TrimEnd()) is { Success: true } m ? $"AkariOS · phase {m.Groups[1].Value} of {m.Groups[2].Value} · {m.Groups[3].Value}" : null;

    /// <summary>ConvertTo-AkariConsoleLine: the segments for one log line; time = HH:mm:ss.</summary>
    public static IReadOnlyList<Segment> Format(string message, string time)
    {
        var m = message.TrimEnd();
        var s = new List<Segment>();
        void Add(string t, ConsoleColor c) => s.Add(new Segment(t, c));
        void Tag(string label, ConsoleColor color, string text, ConsoleColor textColor, string? note)
        {
            Add($"  {time} ", ConsoleColor.DarkGray); Add("[", ConsoleColor.DarkGray); Add(label, color); Add("] ", ConsoleColor.DarkGray); Add(text, textColor);
            if (!string.IsNullOrEmpty(note)) Add($"  {note}", ConsoleColor.DarkGray);
        }
        Match x;
        if ((x = PhaseRx().Match(m)).Success)
        {
            var head = $"Phase {x.Groups[1].Value} of {x.Groups[2].Value}";
            Add("", ConsoleColor.Gray);
            Add($"  {new string(Rule, 2)} ", ConsoleColor.DarkRed); Add(head, ConsoleColor.White); Add($"  {x.Groups[3].Value} ", ConsoleColor.Gray);
            Add(new string(Rule, Math.Max(3, Width - (6 + head.Length + x.Groups[3].Value.Length + 2))), ConsoleColor.DarkRed);
        }
        else if ((x = DoneRx().Match(m)).Success)
        {
            Add("", ConsoleColor.Gray);
            Add($"  {new string(Rule, Width - 2)}", ConsoleColor.DarkGray); Add("", ConsoleColor.Gray);
            Add("  Finished  ", ConsoleColor.White);
            Add(x.Groups[1].Value, x.Groups[1].Value.Contains("failed", StringComparison.OrdinalIgnoreCase) ? ConsoleColor.Yellow : ConsoleColor.Green);
        }
        else if ((x = SummaryFailRx().Match(m)).Success)
        {
            Add("             ", ConsoleColor.Gray); Add("× ", ConsoleColor.Red); Add(x.Groups[1].Value, ConsoleColor.Red); Add($"  {x.Groups[2].Value}", ConsoleColor.DarkGray);
        }
        else if ((x = AppliedRx().Match(m)).Success) Tag("  OK  ", ConsoleColor.Green, x.Groups[1].Value, ConsoleColor.Gray, null);
        else if ((x = RevertedRx().Match(m)).Success) Tag("REVERT", ConsoleColor.Cyan, x.Groups[1].Value, ConsoleColor.Gray, x.Groups[3].Value);
        else if ((x = AlreadyRx().Match(m)).Success) Tag(" SAME ", ConsoleColor.DarkGray, x.Groups[1].Value, ConsoleColor.DarkGray, "already set");
        else if ((x = SkippedRx().Match(m)).Success) Tag(" SKIP ", ConsoleColor.Yellow, x.Groups[1].Value, ConsoleColor.Gray, x.Groups[3].Value);
        else if ((x = FailedRx().Match(m)).Success) Tag("FAILED", ConsoleColor.Red, x.Groups[1].Value, ConsoleColor.Red, x.Groups[3].Value);
        else if ((x = SafeRx().Match(m)).Success) Tag(" WAIT ", ConsoleColor.DarkCyan, x.Groups[1].Value, ConsoleColor.Gray, "in Safe Mode");
        else if ((x = WarnRx().Match(m)).Success)
        {
            var error = x.Groups[1].Value == "Error";
            Tag(error ? "ERROR " : " WARN ", error ? ConsoleColor.Red : ConsoleColor.Yellow, x.Groups[2].Value, ConsoleColor.Gray, null);
        }
        else if (RestartRx().IsMatch(m))
        {
            Add("", ConsoleColor.Gray); Add($"  {time} ", ConsoleColor.DarkGray); Add("▸ ", ConsoleColor.Yellow); Add(m, ConsoleColor.Yellow);
        }
        else { Add($"  {time} ", ConsoleColor.DarkGray); Add("         ", ConsoleColor.Gray); Add(m, ConsoleColor.Gray); }
        return s;
    }
}
