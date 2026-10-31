using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

public sealed class RunnerTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _stateFile = Path.Combine(Path.GetTempPath(), $"akari-runner-{Guid.NewGuid():N}.json");
    private readonly RegistryEngine _reg;
    private readonly FakeSystem _pc = new();
    private readonly MemoryLog _log = new();
    private readonly FakeExplorer _explorer = new();
    private readonly FakeHandoff _handoff = new();
    private readonly Dictionary<string, ITweakCode> _codes = [];
    private readonly MemorySourceFiles _files = new();

    public RunnerTests() => _reg = new RegistryEngine(_key.Paths);

    public void Dispose()
    {
        _key.Dispose();
        File.Delete(_stateFile);
    }

    private sealed class FakeExplorer : IExplorer
    {
        public int Restarts { get; private set; }
        public void Restart() => Restarts++;
    }

    private sealed class FakeHandoff : ISafeModeHandoff
    {
        public List<PlanItem>? Items { get; private set; }
        public void Start(IReadOnlyList<PlanItem> items) => Items = items.ToList();
    }

    /// <summary>Records what the Runner asked of a Tweak's C#.</summary>
    private sealed class Code : ITweakCode
    {
        public List<string> Calls { get; } = [];
        public Exception? Fail { get; init; }
        public TweakState? Detected { get; init; }
        public TweakState Detect(Tweak tweak, TweakContext c) => Detected ?? throw new IOException("can't tell");
        public void Apply(Tweak tweak, TweakContext c, object? value) { Calls.Add($"Apply {value}"); if (Fail != null) throw Fail; }
        public void Revert(Tweak tweak, TweakContext c, object? value) { Calls.Add($"Revert {value}"); if (Fail != null) throw Fail; }
        public void After(Tweak tweak, TweakContext c, TweakMode mode) => Calls.Add($"After {mode}");
        public void Prepare(Tweak tweak, TweakContext c) { Calls.Add("Prepare"); if (Fail != null) throw Fail; }
        public object? ChoiceValue(Tweak tweak, TweakContext c) => Calls.LastOrDefault(x => x.StartsWith("Apply"))?[6..] ?? "Default";
    }

    private void Add(string id, string body, string kind = "", ITweakCode? code = null, string head = "")
    {
        _files.Add($"src/Tweaks/Optimize/Gaming/{id}.ps1", $$"""
            {{head}}
            @{ Id = '{{id}}'; Name = '{{id}} name'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'x'{{kind}}
            {{body}}
            }
            """);
        if (code != null) _codes[id] = code;
    }

    private (Runner Runner, LoadResult Loaded) Make(Func<bool>? inSafeMode = null, bool handoff = true)
    {
        var loaded = new Loader(_files, _codes).Load();
        Assert.DoesNotContain(loaded.Problems, p => p.Level == "Error");
        var ctx = new TweakContext(_reg, _pc, _files, _log);
        var remembered = new JsonRememberedState(_stateFile);
        return (new Runner(ctx, new States(ctx, remembered), remembered, _explorer, handoff ? _handoff : null, inSafeMode), loaded);
    }

    private static string Row(string name, int value = 0, string def = "1", string key = "Game") =>
        $"@{{ Path = 'HKCU:\\Software\\Akari\\{key}'; Name = '{name}'; Type = 'DWord'; Value = {value}; Default = {def} }}";

    private Outcome One(string id, TweakMode mode, object? value = null)
    {
        var (runner, loaded) = Make();
        return runner.Run(loaded.Find(id)!, mode, value);
    }

    [Fact]
    public void A_registry_toggle_applies_reverts_and_knows_already()
    {
        Add("dvr", $"Reboot = $true\nRegistry = @( {Row("A")}, {Row("B", 5, "$null")} )");
        Assert.Equal(new Outcome("dvr", TweakMode.Apply, OutcomeKind.Applied, true), One("dvr", TweakMode.Apply));
        Assert.Equal(0u, _reg.GetValue(@"HKCU:\Software\Akari\Game", "A"));
        Assert.Equal(OutcomeKind.Already, One("dvr", TweakMode.Apply).Kind);
        Assert.Equal(OutcomeKind.Reverted, One("dvr", TweakMode.Revert).Kind);
        Assert.Null(_reg.GetValue(@"HKCU:\Software\Akari\Game", "B"));
        Assert.Equal(OutcomeKind.Already, One("dvr", TweakMode.Revert).Kind);
        Assert.Equal(["Applied: dvr name", "Already: dvr name", "Reverted: dvr name", "Already: dvr name"], _log.Lines);
    }

    [Fact]
    public void Skips_and_refusals()
    {
        Add("w10", $"Requires = 'Win10'\nRegistry = @( {Row("A")} )");
        Add("act", "Apply = { 1 }", "; Kind = 'Action'", new Code(), "# Action: one shot.");
        Add("ps-only", "Apply = { 1 }; Revert = { 2 }");
        Add("app", "Winget = '7zip.7zip'", "; Kind = 'Action'", head: "# Action: an app.");
        Assert.Equal((OutcomeKind.Skipped, "needs Win10"), (One("w10", TweakMode.Apply).Kind, One("w10", TweakMode.Apply).Message));
        Assert.Equal((OutcomeKind.Skipped, "Action has no Revert"), (One("act", TweakMode.Revert).Kind, One("act", TweakMode.Revert).Message));
        Assert.Equal((OutcomeKind.Failed, "Value is only for Choices"), (One("act", TweakMode.Apply, 3).Kind, One("act", TweakMode.Apply, 3).Message));
        Assert.Contains("only the PowerShell app", One("ps-only", TweakMode.Apply).Message);
        Assert.Contains("winget", One("app", TweakMode.Apply).Message);
        Assert.Equal(OutcomeKind.Failed, One("app", TweakMode.Apply).Kind);
    }

    [Fact]
    public void An_entry_waits_for_its_kind()
    {
        var g = new TweakGroup { Id = "appx", Name = "R", Section = "Apps", Category = "Remove", EntryKind = EntryKind.AppxRemove, Source = "x" };
        var entry = Loader.ResolveEntry([g], "appx/Microsoft.BingNews")!;
        var (runner, _) = Make();
        var o = runner.Run(entry, TweakMode.Apply);
        Assert.Equal(OutcomeKind.Failed, o.Kind);
        Assert.Contains("this list's changes", o.Message);
    }

    private const string Choice = """
        Registry    = @{ Path = 'HKLM:\SYSTEM\Akari'; Name = 'Prio'; Type = 'DWord' }
        Choices     = @( @{ Value = 0x26; Label = 'short' }, @{ Value = 0x18; Label = 'long' } )
        Editable    = $true
        Recommended = 0x26
        Default     = $null
        """;

    [Fact]
    public void A_choice_sets_its_recommended_or_picked_value()
    {
        Add("prio", Choice, "; Kind = 'Choice'");
        Assert.Equal(OutcomeKind.Applied, One("prio", TweakMode.Apply).Kind);
        Assert.Equal(0x26u, _reg.GetValue(@"HKLM:\SYSTEM\Akari", "Prio"));
        Assert.Equal(OutcomeKind.Applied, One("prio", TweakMode.Apply, 0x18).Kind);
        Assert.Equal(0x18u, _reg.GetValue(@"HKLM:\SYSTEM\Akari", "Prio"));
        Assert.Equal(OutcomeKind.Already, One("prio", TweakMode.Apply, 24).Kind);
        Assert.Equal(OutcomeKind.Reverted, One("prio", TweakMode.Revert).Kind);
        Assert.Null(_reg.GetValue(@"HKLM:\SYSTEM\Akari", "Prio"));
    }

    [Fact]
    public void A_choice_over_many_settings_runs_its_csharp_with_the_value()
    {
        var code = new Code();
        Add("svc", """
            Value = { Get-Pick }; Apply = { Set-Pick $AkariValue }; Revert = { Set-Pick 'Default' }
            Choices = @( @{ Value = 'Off'; Label = 'Off' }, @{ Value = 'Light'; Label = 'Light' }, @{ Value = 'Default'; Label = 'Windows' } )
            Recommended = 'Off'; Default = 'Default'
            """, "; Kind = 'Choice'", code);
        Assert.Equal(OutcomeKind.Applied, One("svc", TweakMode.Apply, "Light").Kind);
        Assert.Equal(OutcomeKind.Applied, One("svc", TweakMode.Apply).Kind);
        Assert.Equal(OutcomeKind.Reverted, One("svc", TweakMode.Revert).Kind);
        Assert.Equal(["Apply Light", "Apply Off", "Revert Default"], code.Calls);
    }

    [Fact]
    public void A_toggle_with_code_runs_it_and_remembers()
    {
        var code = new Code();
        Add("mem", "Apply = { Disable-MMAgent }; Revert = { Enable-MMAgent }", code: code);
        Assert.Equal(OutcomeKind.Applied, One("mem", TweakMode.Apply).Kind);
        Assert.True(new JsonRememberedState(_stateFile).Get("mem"));
        Assert.Equal(OutcomeKind.Already, One("mem", TweakMode.Apply).Kind);
        Assert.Equal(OutcomeKind.Reverted, One("mem", TweakMode.Revert).Kind);
        Assert.False(new JsonRememberedState(_stateFile).Get("mem"));
        Assert.Equal(["Apply ", "Revert "], code.Calls);
    }

    [Fact]
    public void A_failure_is_an_outcome_with_its_message()
    {
        Add("bad", "Apply = { 1 }; Revert = { 2 }", code: new Code { Fail = new IOException("disk said no") });
        Assert.Equal(new Outcome("bad", TweakMode.Apply, OutcomeKind.Failed, false, "disk said no"), One("bad", TweakMode.Apply));
        Assert.Contains("Failed: bad name: disk said no", _log.Lines);
    }

    [Fact]
    public void After_runs_after_the_rows_both_ways()
    {
        var code = new Code();
        Add("task", $"Registry = @( {Row("A")} )\nAfter = {{ Set-Task }}", code: code);
        One("task", TweakMode.Apply);
        One("task", TweakMode.Revert);
        Assert.Equal(["After Apply", "After Revert"], code.Calls);
    }

    [Fact]
    public void An_action_that_is_already_done()
    {
        Add("done", "Apply = { 1 }; Detect = { $true }", "; Kind = 'Action'", new Code { Detected = TweakState.Optimized }, "# Action: one shot.");
        Add("todo", "Apply = { 1 }; Detect = { $false }", "; Kind = 'Action'", new Code { Detected = TweakState.Default }, "# Action: one shot.");
        Assert.Equal(OutcomeKind.Already, One("done", TweakMode.Apply).Kind);
        Assert.Equal(OutcomeKind.Applied, One("todo", TweakMode.Apply).Kind);
    }

    [Fact]
    public void A_plan_runs_in_order_with_restarts_last_and_explorer_once()
    {
        var reboot1 = new Code();
        var reboot2 = new Code();
        Add("a", $"Explorer = $true\nRegistry = @( {Row("A")} )");
        Add("b", $"Explorer = $true\nRegistry = @( {Row("B")} )");
        Add("r1", "Apply = { shutdown /r /t 0 }", "; Kind = 'Action'", reboot1, "# Action: restarts.");
        Add("r2", "Restarts = $true; Apply = { ddu.exe -Restart }", "; Kind = 'Action'", reboot2, "# Action: restarts.");
        Add("c", $"Registry = @( {Row("C")} )");
        var (runner, loaded) = Make();
        var progress = new List<RunProgress>();
        var outcomes = runner.Run([new("r1", TweakMode.Apply), new("a", TweakMode.Apply), new("nope", TweakMode.Apply), new("r2", TweakMode.Apply), new("b", TweakMode.Apply), new("c", TweakMode.Apply)],
            loaded.Find, new SyncProgress(progress));

        Assert.Equal(["a", "nope", "b", "c", "r1", "r2"], outcomes.Select(o => o.Id));
        Assert.Equal([OutcomeKind.Applied, OutcomeKind.Failed, OutcomeKind.Applied, OutcomeKind.Applied, OutcomeKind.Applied, OutcomeKind.Skipped], outcomes.Select(o => o.Kind));
        Assert.Equal(1, _explorer.Restarts);
        Assert.Single(reboot1.Calls);
        Assert.Empty(reboot2.Calls);
        Assert.Equal(5, progress[0].Total);
        Assert.Contains(progress, p => p.Step == "Restarting Explorer");
        Assert.Contains("Last: r1 name (restarts the PC)", _log.Lines);

        // nothing changed with Explorer = $true: no restart
        runner.Run(["a", "b"], TweakMode.Apply, loaded.Find);
        Assert.Equal(1, _explorer.Restarts);
    }

    private sealed class SyncProgress(List<RunProgress> list) : IProgress<RunProgress>
    {
        public void Report(RunProgress value) => list.Add(value);
    }

    [Fact]
    public void Safe_mode_tweaks_are_prepared_and_handed_off()
    {
        var ready = new Code();
        Add("sm", $"SafeMode = $true\nPrepare = {{ Get-Ddu }}\nRegistry = @( {Row("S")} )", code: ready);
        Add("sm-fails", $"SafeMode = $true\nPrepare = {{ Get-Ddu }}\nRegistry = @( {Row("F")} )", code: new Code { Fail = new IOException("offline") });
        Add("r1", "Apply = { Restart-Computer }", "; Kind = 'Action'", new Code(), "# Action: restarts.");
        Add("now", $"Registry = @( {Row("N")} )");
        var (runner, loaded) = Make();
        var outcomes = runner.Run([new("sm", TweakMode.Apply), new("sm-fails", TweakMode.Apply), new("r1", TweakMode.Apply), new("now", TweakMode.Apply)], loaded.Find);

        Assert.Equal(["now", "sm-fails", "r1", "sm"], outcomes.Select(o => o.Id));
        Assert.Equal(new Outcome("sm", TweakMode.Apply, OutcomeKind.Applied, true, "in Safe Mode, after the restart"), outcomes[3]);
        Assert.Equal((OutcomeKind.Failed, "offline"), (outcomes[1].Kind, outcomes[1].Message));
        Assert.Equal(OutcomeKind.Skipped, outcomes[2].Kind);
        Assert.Equal(["sm"], _handoff.Items!.Select(i => i.Id));
        Assert.Equal(["Prepare"], ready.Calls);
        Assert.Null(_reg.GetValue(@"HKCU:\Software\Akari\Game", "S"));
    }

    [Fact]
    public void In_safe_mode_they_run_now_and_without_a_handoff_they_fail()
    {
        Add("sm", $"SafeMode = $true\nRegistry = @( {Row("S")} )");
        var (inSafe, loaded) = Make(inSafeMode: () => true);
        Assert.Equal(OutcomeKind.Applied, inSafe.Run(["sm"], TweakMode.Apply, loaded.Find).Single().Kind);
        Assert.Null(_handoff.Items);

        var (noHandoff, _) = Make(handoff: false);
        var o = noHandoff.Run(["sm"], TweakMode.Revert, loaded.Find).Single();
        Assert.Equal(OutcomeKind.Failed, o.Kind);
        Assert.Contains("Safe Mode", o.Message);
    }

    [Theory]
    [InlineData("Apply = { shutdown.exe -r -t 5 }", TweakMode.Apply, true)]
    [InlineData("Apply = { bcdedit /set {current} safeboot minimal }", TweakMode.Apply, true)]
    [InlineData("Apply = { 1 }; Revert = { Restart-Computer -Force }", TweakMode.Revert, true)]
    [InlineData("Apply = { shutdown /s }", TweakMode.Apply, false)]
    [InlineData("Restarts = $true; Apply = { 1 }", TweakMode.Apply, true)]
    [InlineData("Restarts = $true; Apply = { 1 }; Revert = { 2 }", TweakMode.Revert, false)]
    public void Which_changes_restart_the_pc(string body, TweakMode mode, bool restarts)
    {
        // one with no Revert is an Action (a Toggle needs both)
        var action = !body.Contains("Revert");
        Add("x", body, action ? "; Kind = 'Action'" : "", head: action ? "# Action: restarts." : "");
        var t = new Loader(_files, _codes).Load().Find("x")!;
        Assert.Equal(restarts, Runner.Restarts(t, mode));
    }
}
