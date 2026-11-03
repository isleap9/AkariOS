using System.Text.Json;
using AkariOS.Core.Data;

namespace AkariOS.Tweaks.Tests;

/// <summary>Reading the blocks oracle's lines (Oracle/Invoke-TweakBlocks.ps1) and checking the C# side against them.</summary>
internal static class BlockLines
{
    public static List<string> Lines(JsonElement e, string id, string block) =>
        e.GetProperty(id).GetProperty(block).EnumerateArray().Select(l => l.GetString()!).ToList();

    /// <summary>Detect's "result" line.</summary>
    public static string Result(JsonElement e, string id) => Lines(e, id, "Detect").Single(l => l.StartsWith("result ", StringComparison.Ordinal))[7..];

    /// <summary>The lines of the given kinds ("stop", "task", …), in order.</summary>
    public static List<string> Of(IEnumerable<string> lines, params string[] kinds) => lines.Where(l => kinds.Contains(l.Split(' ')[0])).ToList();

    public static string Hex(object? v) => v is byte[] b ? string.Join(",", b.Select(x => x.ToString("x2"))) : PsSemantics.Text(v) ?? "";

    /// <summary>What the PowerShell block wrote holds in the test key now: values set (and their kind), values removed,
    /// keys deleted or made (the last of the two counts).</summary>
    public static void AssertWrites(TweakHarness h, IReadOnlyList<string> ps)
    {
        Assert.Contains(ps, l => l.Split(' ')[0] is "set" or "remove" or "delkey" or "newkey");
        var keys = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        foreach (var l in ps)
        {
            if (l.StartsWith("set ", StringComparison.Ordinal))
            {
                var p = l[4..].Split('|');
                Assert.True(Hex(h.Get(p[0], p[1])) == p[2], $"{p[0]}\\{p[1]}: {Hex(h.Get(p[0], p[1]))}, not {p[2]}");
                Assert.Equal(p[3], h.Engine.Registry.GetKind(p[0], p[1])?.ToString());
            }
            else if (l.StartsWith("remove ", StringComparison.Ordinal))
            {
                var p = l[7..].Split('|');
                Assert.True(h.Get(p[0], p[1]) is null, $"{p[0]}\\{p[1]} is still there");
            }
            else if (l.StartsWith("delkey ", StringComparison.Ordinal)) keys[l[7..]] = false;
            else if (l.StartsWith("newkey ", StringComparison.Ordinal)) keys[l[7..]] = true;
        }
        foreach (var (k, exists) in keys) Assert.True(h.Engine.Registry.KeyExists(k) == exists, $"{k} {(exists ? "missing" : "still there")}");
    }
}
