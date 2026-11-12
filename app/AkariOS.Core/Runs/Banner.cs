using System.Text.RegularExpressions;

namespace AkariOS.Core.Runs;

/// <summary>
/// The console banner's logo (Write-AkariBanner / Get-AkariBannerArt): src/Assets/ascii.txt trimmed to its drawing,
/// scaled to 0.7 of its rows and 0.8 of its columns; each cell is the most common character of the area it covers
/// ('=' counted as '+'), a drawn one over a space on a tie.
/// </summary>
public static partial class Banner
{
    public const string ArtFile = "src/Assets/ascii.txt";

    public static IReadOnlyList<string> Art(string text, double scale = 0.7, double wide = 0.8)
    {
        var rows = text.Replace("\r\n", "\n").Split('\n').Select(r => r.TrimEnd()).ToList();
        var first = rows.FindIndex(r => r.Length > 0);
        var last = rows.FindLastIndex(r => r.Length > 0);
        if (first < 0) return [];
        rows = rows.GetRange(first, last - first + 1);
        var indent = rows.Where(r => r.Length > 0).Min(r => r.Length - r.TrimStart().Length);
        rows = rows.Select(r => r.Length >= indent ? r[indent..] : "").ToList();
        var w = rows.Max(r => r.Length);
        rows = rows.Select(r => r.PadRight(w)).ToList();
        var th = (int)Math.Ceiling(rows.Count * scale);
        var tw = (int)Math.Ceiling(w * wide);
        var output = new List<string>();
        for (var r = 0; r < th; r++)
        {
            var r0 = (int)Math.Floor(r / scale);
            var r1 = Math.Max(r0, (int)Math.Min(rows.Count - 1, Math.Floor((r + 1) / scale) - 1));
            var line = new char[tw];
            for (var c = 0; c < tw; c++)
            {
                var c0 = (int)Math.Floor(c / wide);
                var c1 = Math.Max(c0, (int)Math.Min(w - 1, Math.Floor((c + 1) / wide) - 1));
                var n = new Dictionary<char, int>();
                for (var y = r0; y <= r1; y++)
                    for (var x = c0; x <= c1; x++)
                    {
                        var ch = rows[y][x] == '=' ? '+' : rows[y][x];
                        n[ch] = n.GetValueOrDefault(ch) + 1;
                    }
                line[c] = n.OrderByDescending(kv => kv.Value).ThenBy(kv => kv.Key == ' ').First().Key;
            }
            output.Add(new string(line).TrimEnd());
        }
        return output;
    }

    /// <summary>A row's runs: the logo's lines ('+' / '=': dark grey) and the rest (white).</summary>
    public static IReadOnlyList<(string Text, bool Line)> Strokes(string row) =>
        Stroke().Matches(row).Select(m => (m.Value, m.Value[0] is '+' or '=')).ToList();

    [GeneratedRegex("[+=]+|[^+=]+")]
    private static partial Regex Stroke();
}
