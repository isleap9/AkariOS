using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native Loader against the PowerShell app's (Oracle/Export-Tweaks.ps1 runs Get-AkariTweaks on src\Tweaks):
/// the same Tweaks with the same fields, the same Groups, the same Problems.
/// </summary>
public class LoaderOracleTests
{
    private static readonly Lazy<JsonElement> PowerShell = new(() => Oracle.Run("Export-Tweaks.ps1", "-Src", Repo.Src));

    private static readonly Lazy<LoadResult> Native = new(() =>
        new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load());

    [Fact]
    public void The_real_tree_loads_without_problems()
    {
        var errors = Native.Value.Problems.Where(p => p.Level == "Error").Select(p => $"{p.File}: {p.Message}").ToList();
        Assert.True(errors.Count == 0, string.Join("\n", errors));
    }

    [Fact]
    public void The_same_problems()
    {
        var ps = PowerShell.Value.GetProperty("Problems").EnumerateArray().Select(p => $"{p.GetProperty("File").GetString()} {p.GetProperty("Level").GetString()}").Order().ToList();
        var mine = Native.Value.Problems.Select(p => $"{p.File} {p.Level}").Order().ToList();
        Assert.Equal(ps, mine);
    }

    [Fact]
    public void The_same_groups()
    {
        var ps = PowerShell.Value.GetProperty("Groups").EnumerateArray().ToDictionary(g => g.GetProperty("Id").GetString()!);
        Assert.Equal(ps.Keys.Order(), Native.Value.Groups.Select(g => g.Id).Order());
        foreach (var g in Native.Value.Groups)
        {
            var p = ps[g.Id];
            Assert.Equal(p.GetProperty("EntryKind").GetString(), g.EntryKind.Name);
            Assert.Equal(p.GetProperty("Rows").GetInt32(), g.Rows.Count);
            Assert.Equal(p.GetProperty("KeepNames").EnumerateArray().Select(k => k.GetString()), g.KeepNames);
            Assert.Equal(p.GetProperty("Source").GetString(), g.Source);
        }
    }

    [Fact]
    public void The_same_tweaks_with_the_same_fields()
    {
        var ps = PowerShell.Value.GetProperty("Tweaks").EnumerateArray().ToList();
        var mine = Native.Value.Tweaks.ToDictionary(t => t.Id);
        Assert.Equal(ps.Select(p => p.GetProperty("Id").GetString()), Native.Value.Tweaks.Select(t => t.Id));
        var diffs = new List<string>();
        foreach (var p in ps)
        {
            var t = mine[p.GetProperty("Id").GetString()!];
            void Same(string field, object? native)
            {
                var v = p.GetProperty(field);
                var ok = native switch
                {
                    null => v.ValueKind == JsonValueKind.Null,
                    bool b => v.ValueKind == (b ? JsonValueKind.True : JsonValueKind.False),
                    int n => v.ValueKind == JsonValueKind.Number && v.GetInt32() == n,
                    IEnumerable<string> list => v.ValueKind == JsonValueKind.Array && v.EnumerateArray().Select(x => x.GetString()).SequenceEqual(list),
                    _ => v.ValueKind == JsonValueKind.String && v.GetString() == native.ToString(),
                };
                if (!ok) diffs.Add($"{t.Id}.{field}: {native}, PowerShell has {v}");
            }
            Same("Name", t.Name); Same("Description", t.Description); Same("Section", t.Section); Same("Category", t.Category);
            Same("Kind", t.Kind.ToString()); Same("Risk", t.Risk.ToString()); Same("Button", t.Button); Same("Confirm", t.Confirm);
            Same("Reboot", t.Reboot); Same("SafeMode", t.SafeMode); Same("Restarts", t.Restarts); Same("Explorer", t.Explorer);
            Same("AkariOS", t.AkariOS); Same("Guided", t.Guided); Same("Editable", t.Editable); Same("Keep", t.Keep);
            Same("Requires", t.Requires); Same("Winget", t.Winget); Same("WingetSource", t.WingetSource); Same("AppType", t.AppType);
            Same("StoreId", t.StoreId); Same("Group", t.Group); Same("Package", t.Package); Same("Source", t.Source);
            if (!t.RowsAreCode) Same("Rows", t.Registry?.Count ?? 0);
            if (t.Fields.Get("Choices") is not PsCode) Same("Choices", t.Choices.Count);
        }
        Assert.True(diffs.Count == 0, $"{diffs.Count} differences:\n" + string.Join("\n", diffs.Take(60)));
    }
}
