using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native Guided rules against the PowerShell app's (Oracle/Export-Steps.ps1) on the real Tweaks: the same
/// Sections and Category cards on two made-up PCs, the same pending change (or none) in every scenario, the same
/// row tooltips.
/// </summary>
public class StepsOracleTests
{
    private static readonly Lazy<JsonElement> PowerShell = new(() => Oracle.Run("Export-Steps.ps1", "-Src", Repo.Src));

    private static readonly Lazy<IReadOnlyList<Tweak>> Loaded = new(() =>
        new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load().Tweaks);

    public static TheoryData<string> Pcs => ["Win11", "Win10"];

    private static FakeSystem Pc(string name) => name == "Win11"
        ? new FakeSystem { Gpus = [new Gpu("x", "GeForce", "NVIDIA")] }
        : new FakeSystem { Build = 19045, Edition = "Core", Chassis = Chassis.Laptop };

    [Theory, MemberData(nameof(Pcs))]
    public void The_same_sections_and_cards(string pc)
    {
        var ps = PowerShell.Value.GetProperty("Groups").GetProperty(pc).EnumerateArray().Select(s =>
            $"{s.GetProperty("Section").GetString()} | {s.GetProperty("Header").GetString()} | " +
            string.Join("; ", s.GetProperty("Categories").EnumerateArray().Select(c =>
                $"{c.GetProperty("Name").GetString()}: {string.Join(",", c.GetProperty("Ids").EnumerateArray().Select(i => i.GetString()))}")));
        var mine = Selection.StepGroups(Loaded.Value, Pc(pc)).Select(s =>
            $"{s.Section} | {s.Header} | {string.Join("; ", s.Categories.Select(c => $"{c.Name}: {string.Join(",", c.Ids)}"))}");
        Assert.True(mine.Count() >= 4, "the four Guided Sections");
        Assert.Equal(ps, mine);
    }

    // a value as PowerShell writes "$value"
    private static string? AsText(object? v) => v is byte[] b ? string.Join(" ", b) : PsSemantics.Text(v);

    private static string Item(IDictionary<string, Pending> sel, Tweak t) =>
        sel.TryGetValue(t.Id, out var p) ? $"{p.Mode} {p.HasValue} {(p.HasValue ? AsText(p.Value) : "")} | {p.From} -> {p.To}" : "none";

    private static string Item(JsonElement e) => e.ValueKind == JsonValueKind.String ? e.GetString()!
        : $"{e.GetProperty("Mode").GetString()} {e.GetProperty("HasValue").GetBoolean()} {(e.GetProperty("HasValue").GetBoolean() ? e.GetProperty("Value").GetString() : "")} | {e.GetProperty("From").GetString()} -> {e.GetProperty("To").GetString()}";

    [Fact]
    public void The_same_pending_change_in_every_scenario()
    {
        var ps = PowerShell.Value.GetProperty("Pending");
        foreach (var t in Loaded.Value)
        {
            var def = States.DefaultOn(t, 26100);
            string One(TweakState state, object? target, object? current)
            {
                var sel = new Dictionary<string, Pending>();
                Selection.SetPending(sel, t, state, target, current, def);
                return Item(sel, t);
            }
            var mine = new List<string>();
            if (t.Kind == TweakKind.Choice)
            {
                var first = t.Choices[0].Value;
                foreach (var c in t.Choices)
                {
                    mine.Add(One(TweakState.Unknown, c.Value, null));
                    mine.Add(One(TweakState.Custom, c.Value, first));
                    mine.Add(One(TweakState.Default, c.Value, def));
                }
                mine.Add(One(TweakState.Custom, def, first));
                mine.Add(One(TweakState.Custom, Selection.None, first));
            }
            else
                foreach (var s in new[] { TweakState.Optimized, TweakState.Default, TweakState.Custom, TweakState.Unknown })
                    foreach (var x in new[] { Selection.Optimized, Selection.Default, Selection.None })
                        mine.Add(One(s, x, null));
            var want = ps.GetProperty(t.Id).EnumerateArray().Select(Item).ToList();
            Assert.True(want.SequenceEqual(mine), $"{t.Id}:\n  {string.Join("\n  ", want)}\nvs\n  {string.Join("\n  ", mine)}");
        }
    }

    [Fact]
    public void The_same_row_tips()
    {
        var ps = PowerShell.Value.GetProperty("Tips");
        foreach (var t in Loaded.Value)
            Assert.Equal(ps.GetProperty(t.Id).EnumerateArray().Select(e => e.GetString()),
                new[] { TweakState.Optimized, TweakState.Default, TweakState.Custom, TweakState.Unknown }.Select(s => Selection.RowTip(t, s)));
    }
}
