using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

/// <summary>
/// Run history and Undo (X4, src/Core/History.ps1's rules): which Tweaks Undo puts back exactly, a record written by a
/// Run, every value kind put back as it was (missing ones removed), the plan's three lists, the newest 10 kept and an
/// undone record set aside. Rows on a test key, files in a temp folder.
/// </summary>
public sealed class HistoryTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-history-{Guid.NewGuid():N}");
    private readonly MemorySourceFiles _files = new();
    private readonly MemoryLog _log = new();

    public HistoryTests() => Directory.CreateDirectory(_dir);

    public void Dispose()
    {
        _key.Dispose();
        Directory.Delete(_dir, true);
    }

    private sealed class CountingExplorer : IExplorer
    {
        public int Restarts { get; private set; }
        public void Restart() => Restarts++;
    }

    private sealed class Code : ITweakCode
    {
        public int Reverts { get; private set; }
        public void Apply(Tweak tweak, TweakContext c, object? value) { }
        public void Revert(Tweak tweak, TweakContext c, object? value) => Reverts++;
    }

    private void Add(string id, string fields) =>
        _files.Add($"src/Tweaks/Optimize/Gaming/{id}.ps1",
            $"# Action: a test one\n@{{ Id = '{id}'; Name = '{id} name'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'x'\n{fields}\n}}\n");

    private static string Lists(UndoPlan p) => $"{string.Join(",", p.Exact)}|{string.Join(",", p.Default)}|{string.Join(",", p.Never)}";

    private const string K = @"HKCU:\Software\Akari\Undo";

    [Fact]
    public void A_run_is_recorded_and_undone_value_for_value()
    {
        Add("undo-tog", $$"""
            Explorer = $true
            Registry = @(
                @{ Path = '{{K}}'; Name = 'Dw'; Type = 'DWord'; Value = 0; Default = 1 }
                @{ Path = '{{K}}'; Name = 'Str'; Type = 'String'; Value = 'on'; Default = $null }
                @{ Path = '{{K}}'; Name = 'Exp'; Type = 'ExpandString'; Value = '%TEMP%\on'; Default = $null }
                @{ Path = '{{K}}'; Name = 'Bin'; Type = 'Binary'; Value = '01,02'; Default = $null }
                @{ Path = '{{K}}'; Name = 'Multi'; Type = 'MultiString'; Value = @('x'); Default = $null }
                @{ Path = '{{K}}\Sub'; Name = 'Missing'; Type = 'DWord'; Value = 1; Default = $null }
            )
            """);
        Add("undo-code", "Apply = { }; Revert = { }");
        Add("undo-act", "Kind = 'Action'; Apply = { }");
        var code = new Code();
        var loaded = new Loader(_files, new Dictionary<string, ITweakCode> { ["undo-code"] = code, ["undo-act"] = new Code() }).Load();
        Assert.Equal("", string.Join(" / ", loaded.Problems.Where(p => p.Level == "Error").Select(p => $"{p.File}: {p.Message}")));
        Tweak? Find(string id) => loaded.Tweaks.FirstOrDefault(t => t.Id == id);
        Assert.True(RunHistory.Undoable(Find("undo-tog")!));
        Assert.False(RunHistory.Undoable(Find("undo-code")!));
        Assert.False(RunHistory.Undoable(Find("undo-act")!));

        var reg = new RegistryEngine(_key.Paths);
        reg.SetValue(K, "Dw", 4000000000u, "DWord");
        reg.SetValue(K, "Str", "mine", "String");
        reg.SetValue(K, "Exp", @"%USERPROFILE%\mine", "ExpandString");
        reg.SetValue(K, "Bin", new byte[] { 255, 0 }, "Binary");
        reg.SetValue(K, "Multi", new[] { "a", "b" }, "MultiString");
        var ctx = new TweakContext(reg, new FakeSystem(), _files, _log);
        var remembered = new JsonRememberedState(Path.Combine(_dir, "state.json"));
        var expected = new ExpectedStore(Path.Combine(_dir, "expected.json"));
        var explorer = new CountingExplorer();
        var runner = new Runner(ctx, new States(ctx, remembered), remembered, explorer, expected: expected);
        var history = new RunHistory(Path.Combine(_dir, "history"), reg, _log);

        PlanItem[] plan = [new("undo-tog", TweakMode.Apply), new("undo-code", TweakMode.Apply), new("undo-act", TweakMode.Apply)];
        var outs = history.Record("Guided run", new DateTime(2026, 11, 26, 10, 0, 0), plan, Find, () => runner.Run(plan, Find));
        Assert.All(outs, o => Assert.Equal(OutcomeKind.Applied, o.Kind));
        Assert.Equal("on", reg.GetValue(K, "Str"));
        Assert.True(expected.All().ContainsKey("undo-tog"));

        var r = history.Last()!;
        Assert.Equal("Guided run", r.Name);
        Assert.Equal(["undo-tog"], r.Before.Keys);
        Assert.Equal(["undo-tog:Applied", "undo-code:Applied", "undo-act:Applied"], r.Outcomes.Select(o => $"{o.Id}:{o.Kind}"));
        var p = RunHistory.Plan(r, Find);
        Assert.Equal("undo-tog|undo-code|undo-act", Lists(p));
        Assert.Contains("- 1 setting go back to what it was before the Run", RunHistory.UndoText(r, p, Find));
        Assert.Contains("- 1 go back to Windows' default (they run code, so their earlier values weren't saved): undo-code name", RunHistory.UndoText(r, p, Find));

        var undone = history.Undo(r, Find, runner, explorer, expected);
        Assert.Equal(["undo-code:Reverted", "undo-tog:Reverted"], undone.Select(o => $"{o.Id}:{o.Kind}"));
        Assert.Equal(1, code.Reverts);
        Assert.Equal(2, explorer.Restarts);   // once after the Run, once after Undo
        Assert.Equal(4000000000u, reg.GetValue(K, "Dw"));
        Assert.Equal("mine", reg.GetValue(K, "Str"));
        Assert.Equal((RegistryValueKind.ExpandString, (object)@"%USERPROFILE%\mine"), reg.GetRaw(K, "Exp"));
        Assert.Equal(new byte[] { 255, 0 }, reg.GetValue(K, "Bin"));
        Assert.Equal(new[] { "a", "b" }, reg.GetValue(K, "Multi"));
        Assert.Null(reg.GetValue($@"{K}\Sub", "Missing"));
        // the user's own value now: the drift check leaves it; the record set aside, so nothing is left to undo
        Assert.False(expected.All().ContainsKey("undo-tog"));
        Assert.Null(history.Last());
        Assert.True(File.Exists(Path.ChangeExtension(r.Path, ".undone")));
    }

    [Fact]
    public void Plans_by_each_ids_last_change_and_keeps_the_newest_ten()
    {
        Add("plan-tog", $"Registry = @(@{{ Path = '{K}'; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 }})");
        Add("plan-code", "Apply = { }; Revert = { }");
        var loaded = new Loader(_files, new Dictionary<string, ITweakCode> { ["plan-code"] = new Code() }).Load();
        Tweak? Find(string id) => loaded.Tweaks.FirstOrDefault(t => t.Id == id);
        var r = new HistoryRecord("x", "Run", "", new Dictionary<string, IReadOnlyList<UndoRow>> { ["plan-tog"] = [] },
            [("plan-tog", TweakMode.Apply, OutcomeKind.Already), ("plan-code", TweakMode.Revert, OutcomeKind.Reverted),
             ("gone", TweakMode.Apply, OutcomeKind.Applied), ("plan-tog", TweakMode.Apply, OutcomeKind.Failed)]);
        var p = RunHistory.Plan(r, Find);
        Assert.Equal("||plan-code,gone", Lists(p));

        var history = new RunHistory(Path.Combine(_dir, "keep"), new RegistryEngine(_key.Paths), _log);
        for (var m = 1; m <= 12; m++) history.New($"Run {m}", new DateTime(2026, 1, m));
        Assert.Equal(RunHistory.Keep, Directory.GetFiles(history.Folder).Length);
        Assert.Equal("Run 12", history.Last()!.Name);
    }
}
