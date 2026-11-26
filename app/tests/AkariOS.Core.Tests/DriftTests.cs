using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// The drift check (X3): the rule against src\Core\State.ps1's Test-AkariDrift (Oracle/Export-Drift.ps1), an
/// expected.json the PowerShell app wrote read back here, the Runner recording what each setting should be, and the
/// drifted settings found and turned into a preset. Registry rows on a test key, files in a temp folder.
/// </summary>
public sealed class DriftTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-drift-{Guid.NewGuid():N}");
    private readonly MemorySourceFiles _files = new();

    public DriftTests() => Directory.CreateDirectory(_dir);

    public void Dispose()
    {
        _key.Dispose();
        Directory.Delete(_dir, true);
    }

    private static readonly (string Kind, string Mode, object? Value, string State, object? Current)[] Cases =
    [
        ("Toggle", "Revert", null, "Default", null), ("Toggle", "Revert", null, "Optimized", null), ("Choice", "Revert", null, "Custom", 5),
        ("Toggle", "Apply", null, "Optimized", null), ("Toggle", "Apply", null, "Custom", null), ("Toggle", "Apply", null, "Default", null),
        ("Choice", "Apply", null, "Optimized", 2), ("Choice", "Apply", 3, "Custom", 3), ("Choice", "Apply", 3, "Custom", "3"),
        ("Choice", "Apply", 3, "Optimized", 2), ("Choice", "Apply", 3, "Default", null), ("Choice", "Apply", "high", "Custom", "HIGH"),
        ("Toggle", "Apply", null, "Unknown", null), ("Choice", "Revert", null, "Unknown", null),
    ];

    [Fact]
    public void The_rule_and_the_file_are_powershells()
    {
        var cases = Path.Combine(_dir, "cases.json");
        var expected = Path.Combine(_dir, "expected.json");
        File.WriteAllText(cases, JsonSerializer.Serialize(Cases.Select(c => new { c.Kind, c.Mode, c.Value, c.State, c.Current })));
        var ps = Oracle.Run("Export-Drift.ps1", "-Src", Repo.Src, "-Cases", cases, "-Expected", expected).EnumerateArray().Select(e => e.GetBoolean()).ToList();
        Assert.Equal(ps, Cases.Select(c => Drift.IsDrift(Enum.Parse<TweakKind>(c.Kind), Enum.Parse<TweakMode>(c.Mode), c.Value,
            Enum.Parse<TweakState>(c.State), c.Current)).ToList());

        var all = new ExpectedStore(expected).All();
        Assert.Equal(["cho-3", "cho-back", "cho-rec", "cho-text", "tog-off", "tog-on"], all.Keys.Order(StringComparer.Ordinal));
        Assert.Equal((TweakMode.Apply, (object?)3), (all["cho-3"].Mode, all["cho-3"].Value));
        Assert.Equal("high", all["cho-text"].Value);
        Assert.Null(all["cho-rec"].Value);
        Assert.Equal((TweakMode.Revert, (object?)null), (all["cho-back"].Mode, all["cho-back"].Value));
        Assert.True(DateTime.TryParse(all["tog-on"].When, out _));
    }

    private void Add(string id, string kind, string body) =>
        _files.Add($"src/Tweaks/Optimize/Gaming/{id}.ps1",
            $"# Action: a test one\n@{{ Id = '{id}'; Name = '{id} name'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'x'{kind}\n{body}\n}}\n");

    private sealed class NoExplorer : IExplorer
    {
        public void Restart() { }
    }

    [Fact]
    public void The_runner_records_and_the_check_finds_what_went_back()
    {
        Add("b-tog", "", @"Registry = @(@{ Path = 'HKCU:\Software\Akari\Game'; Name = 'T'; Type = 'DWord'; Value = 0; Default = 1 })");
        Add("a-cho", "; Kind = 'Choice'; Recommended = 2; Default = 1; Choices = @(@{ Value = 1; Label = 'One' }, @{ Value = 2; Label = 'Two' }, @{ Value = 3; Label = 'Three' })", @"Registry = @(@{ Path = 'HKCU:\Software\Akari\Game'; Name = 'C'; Type = 'DWord' })");
        Add("c-act", "; Kind = 'Action'", "Apply = { }");
        var loaded = new Loader(_files, new Dictionary<string, ITweakCode>()).Load();
        Assert.Equal("", string.Join(" / ", loaded.Problems.Where(p => p.Level == "Error").Select(p => $"{p.File}: {p.Message}")));
        var reg = new RegistryEngine(_key.Paths);
        var ctx = new TweakContext(reg, new FakeSystem(), _files, new MemoryLog());
        var remembered = new JsonRememberedState(Path.Combine(_dir, "state.json"));
        var store = new ExpectedStore(Path.Combine(_dir, "expected.json"));
        var states = new States(ctx, remembered);
        var runner = new Runner(ctx, states, remembered, new NoExplorer(), expected: store);
        Tweak T(string id) => loaded.Tweaks.Single(t => t.Id == id);

        Assert.Equal(OutcomeKind.Applied, runner.Run(T("b-tog"), TweakMode.Apply).Kind);
        Assert.Equal(OutcomeKind.Already, runner.Run(T("b-tog"), TweakMode.Apply).Kind);
        Assert.Equal(OutcomeKind.Applied, runner.Run(T("a-cho"), TweakMode.Apply, 3).Kind);
        Assert.Equal(OutcomeKind.Skipped, runner.Run(T("c-act"), TweakMode.Revert).Kind);
        var all = store.All();
        Assert.Equal(["a-cho", "b-tog"], all.Keys.Order(StringComparer.Ordinal));
        Assert.Equal(3, all["a-cho"].Value);
        Assert.Empty(Drift.Find(loaded.Tweaks, all, states, new FakeSystem()));

        reg.SetValue(@"HKCU:\Software\Akari\Game", "T", 1, "DWord");
        reg.SetValue(@"HKCU:\Software\Akari\Game", "C", 2, "DWord");
        var drift = Drift.Find(loaded.Tweaks, store.All(), states, new FakeSystem());
        Assert.Equal(["a-cho=Apply:3:Optimized", "b-tog=Apply::Default"], drift.Select(d => $"{d.Id}={d.Mode}:{d.Value}:{d.State}"));

        var preset = Drift.ToPreset(drift);
        Assert.Equal(["a-cho:True:3", "b-tog:False:"], preset.Entries.Select(e => $"{e.Id}:{e.HasValue}:{e.Value}"));
        Assert.Equal(["a-cho:Apply:3", "b-tog:Apply:"], PresetStore.Resolve(preset, loaded.Tweaks).Items.Select(i => $"{i.Id}:{i.Mode}:{i.Value}"));

        // a Revert (here Already: Windows put it back) is expected Default from now on
        Assert.Equal(OutcomeKind.Already, runner.Run(T("b-tog"), TweakMode.Revert).Kind);
        Assert.Equal(TweakMode.Revert, store.All()["b-tog"].Mode);
        Assert.Equal(["a-cho"], Drift.Find(loaded.Tweaks, store.All(), states, new FakeSystem()).Select(d => d.Id));
    }
}
