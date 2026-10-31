using System.Globalization;
using System.Text;
using System.Text.Json;
using AkariOS.Core.Data;

namespace AkariOS.Core.Tests;

/// <summary>
/// PsData against PowerShell itself, over every file the two apps share: Oracle/Export-PsData.ps1 reads them as the
/// PowerShell app does and the values must agree. A value PsData keeps as code (PsCode) is not compared.
/// </summary>
public class PsDataOracleTests
{
    /// <summary>The shared files by their src/ path: one-file Tweaks, and every .psd1 the native app reads.</summary>
    internal static IReadOnlyList<string> SharedFiles { get; } = FindSharedFiles();

    private static readonly Lazy<JsonElement> PowerShell = new(RunOracle);

    private static List<string> FindSharedFiles()
    {
        var src = Repo.Src;
        var files = new List<string>();
        foreach (var section in Directory.GetDirectories(Path.Combine(src, "Tweaks")))
        {
            foreach (var category in Directory.GetDirectories(section))
                files.AddRange(Directory.GetFiles(category, "*.ps1"));
            files.AddRange(Directory.GetFiles(section, "*.psd1", SearchOption.AllDirectories));
        }
        files.AddRange(Directory.GetFiles(Path.Combine(src, "Core", "Iso", "Data"), "*.psd1", SearchOption.AllDirectories));
        files.AddRange(Directory.GetFiles(Path.Combine(src, "UI"), "*.psd1"));
        return files.Select(f => "src/" + Path.GetRelativePath(src, f).Replace('\\', '/')).Order(StringComparer.Ordinal).ToList();
    }

    internal static string FullPath(string rel) => Path.Combine(Repo.Root, rel.Replace('/', Path.DirectorySeparatorChar));

    internal static PsFile Read(string rel) => PsData.Parse(File.ReadAllText(FullPath(rel)));

    private static JsonElement RunOracle() => Oracle.Run("Export-PsData.ps1", "-Src", Repo.Src).GetProperty("Files");

    [Fact]
    public void Every_shared_file_reads()
    {
        var problems = new List<string>();
        foreach (var rel in SharedFiles)
        {
            try
            {
                var f = Read(rel);
                if (f.Value is not PsHashtable) problems.Add($"{rel}: not a hashtable");
                if (rel.EndsWith(".psd1", StringComparison.Ordinal) && f.HasCode) problems.Add($"{rel}: a .psd1 with code");
            }
            catch (PsDataException e) { problems.Add($"{rel}: {e.Message}"); }
        }
        Assert.True(problems.Count == 0, string.Join("\n", problems));
        Assert.True(SharedFiles.Count > 400, $"only {SharedFiles.Count} shared files found");
    }

    [Fact]
    public void Every_tweak_file_has_an_id()
    {
        var missing = SharedFiles.Where(r => r.EndsWith(".ps1", StringComparison.Ordinal))
            .Where(r => Read(r).Value is not PsHashtable h || h.Get("Id") is not string).ToList();
        Assert.True(missing.Count == 0, string.Join("\n", missing));
    }

    [Fact]
    public void Most_registry_tweaks_are_data_only()
    {
        var tweaks = SharedFiles.Where(r => r.EndsWith(".ps1", StringComparison.Ordinal)).ToList();
        var dataOnly = tweaks.Count(r => !Read(r).HasCode);
        Assert.True(dataOnly > 200, $"{dataOnly} of {tweaks.Count} tweak files are data only");
    }

    [Fact]
    public void PowerShell_reads_the_same_values()
    {
        var oracle = PowerShell.Value;
        var diffs = new List<string>();
        foreach (var rel in SharedFiles)
        {
            if (!oracle.TryGetProperty(rel, out var ps)) { diffs.Add($"{rel}: PowerShell didn't read it"); continue; }
            if (ps.ValueKind == JsonValueKind.Object && ps.TryGetProperty("$error", out var err)) { diffs.Add($"{rel}: PowerShell: {err}"); continue; }
            Same(ps, Read(rel).Value, rel, Path.GetDirectoryName(FullPath(rel))!, diffs);
        }
        Assert.True(diffs.Count == 0, $"{diffs.Count} differences:\n" + string.Join("\n", diffs.Take(60)));
    }

    private static void Same(JsonElement ps, object? mine, string where, string dir, List<string> diffs)
    {
        void Diff(string what) => diffs.Add($"{where}: {what}");
        switch (mine)
        {
            case PsCode:
                return;
            case PsScriptBlock:
                if (!(ps.ValueKind == JsonValueKind.Object && ps.TryGetProperty("$block", out _))) Diff($"a script block, PowerShell has {ps}");
                return;
            case PsImport im:
                var file = PsData.Parse(File.ReadAllText(Path.Combine(dir, im.File)));
                Same(ps, (file.Value as PsHashtable)?.Get(im.Key), $"{where} <- {im.File}.{im.Key}", dir, diffs);
                return;
            case null:
                if (ps.ValueKind != JsonValueKind.Null) Diff($"null, PowerShell has {ps}");
                return;
            case string s:
                if (ps.ValueKind != JsonValueKind.String || ps.GetString() != s) Diff($"'{s}', PowerShell has {ps}");
                return;
            case bool b:
                if (ps.ValueKind != (b ? JsonValueKind.True : JsonValueKind.False)) Diff($"{b}, PowerShell has {ps}");
                return;
            case byte[] bytes:
                var hex = Convert.ToHexString(bytes).ToLowerInvariant();
                if (!(ps.ValueKind == JsonValueKind.Object && ps.TryGetProperty("$bytes", out var h) && h.GetString() == hex)) Diff($"bytes {hex}, PowerShell has {ps}");
                return;
            case int or long or ulong or uint or double or decimal:
                var (num, type) = mine switch
                {
                    double d => (d.ToString("R", CultureInfo.InvariantCulture), "Double"),
                    _ => (Convert.ToString(mine, CultureInfo.InvariantCulture)!, mine.GetType().Name),
                };
                if (!(ps.ValueKind == JsonValueKind.Object && ps.TryGetProperty("$num", out var n) && n.GetString() == num &&
                      ps.TryGetProperty("$type", out var t) && t.GetString() == type))
                    Diff($"{type} {num}, PowerShell has {ps}");
                return;
            case PsHashtable table:
                if (ps.ValueKind != JsonValueKind.Object) { Diff($"a hashtable, PowerShell has {ps.ValueKind}"); return; }
                var theirs = ps.EnumerateObject().ToDictionary(p => p.Name, p => p.Value, StringComparer.OrdinalIgnoreCase);
                foreach (var k in theirs.Keys.Where(k => !table.ContainsKey(k))) Diff($"key {k} only in PowerShell's");
                foreach (var (k, v) in table)
                {
                    if (!theirs.TryGetValue(k, out var pv)) { Diff($"key {k} only in PsData's"); continue; }
                    Same(pv, v, $"{where}.{k}", dir, diffs);
                }
                return;
            case object?[] items:
                if (items.Any(i => i is PsCode)) return;
                if (ps.ValueKind != JsonValueKind.Array) { Diff($"a list of {items.Length}, PowerShell has {ps.ValueKind}"); return; }
                var list = ps.EnumerateArray().ToList();
                if (list.Count != items.Length) { Diff($"{items.Length} items, PowerShell has {list.Count}"); return; }
                for (var i = 0; i < items.Length; i++) Same(list[i], items[i], $"{where}[{i}]", dir, diffs);
                return;
            default:
                Diff($"unexpected {mine.GetType().Name}");
                return;
        }
    }
}
