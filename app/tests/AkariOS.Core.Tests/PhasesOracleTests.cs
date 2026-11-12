using System.Text.Json;
using System.Text.Json.Nodes;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// Runs in phases: the native Phases against the PowerShell app's own Start-AkariPhases and Split-AkariSafeModePhases
/// (Oracle/Export-Phases.ps1), scenario by scenario. Both sides record the same steps (run.json saved, the next boot,
/// Safe Mode off, the restart, each phase's plan, the Prepares, the log lines) and end with the same Run.
/// </summary>
public sealed class PhasesOracleTests
{
    /// <summary>A scenario's Tweak: only what Phases reads.</summary>
    private sealed record T(string Id, string Kind = "Toggle", bool SafeMode = false, bool Restarts = false, bool Prepare = false, string? Requires = null);

    private sealed record R(string Kind, bool Reboot = false, string Message = "");

    private sealed record Scenario(
        string Name, bool Safe, T[] Tweaks, (string Name, string Boot, string[] Items)[] Phases, int Next = 0,
        Dictionary<string, string>? States = null, Dictionary<string, R>? Results = null, string[]? PrepareFails = null);

    // the AkariOS preset's shape: preparation, Safe Mode (a Toggle and DDU, which restarts by itself), the rest
    private static readonly T[] OneClick =
    [
        new("install-a", "Action"), new("ddu-prepare", "Action"),
        new("defender", SafeMode: true), new("ddu-clean", "Action", SafeMode: true, Restarts: true, Prepare: true),
        new("debloat-x"), new("debloat-y"),
    ];

    private static readonly (string, string, string[])[] OneClickPhases =
    [
        ("Preparation", "Normal", ["Apply install-a", "Apply ddu-prepare"]),
        ("Safe Mode: drivers", "SafeMode", ["Apply defender", "Apply ddu-clean"]),
        ("Debloat", "Normal", ["Apply debloat-x", "Apply debloat-y"]),
    ];

    private static readonly Scenario[] Scenarios =
    [
        new("flat", false, [new("a"), new("b")], [("Tweaks", "Normal", ["Apply a", "Revert b"])]),
        new("one-click phase 1", false, OneClick, OneClickPhases),
        new("one-click phase 2 in Safe Mode", true, OneClick, OneClickPhases, Next: 1),
        new("one-click phase 2: DDU could not run", true, OneClick, OneClickPhases, Next: 1,
            Results: new() { ["ddu-clean"] = new("Failed", Message: "DDU is not ready") }),
        new("one-click phase 2: a change failed", true, OneClick, OneClickPhases, Next: 1,
            Results: new() { ["defender"] = new("Failed", Message: "Access denied") }),
        new("one-click phase 3, a reboot", false, OneClick, OneClickPhases, Next: 2,
            Results: new() { ["debloat-y"] = new("Applied", Reboot: true) }),
        new("one-click phase 3, no reboot", false, OneClick, OneClickPhases, Next: 2),
        new("resumed in the wrong mode", false, OneClick, OneClickPhases, Next: 1),
        new("split off", false,
            [new("a"), new("safe-1", SafeMode: true), new("safe-done", SafeMode: true), new("safe-action", "Action", SafeMode: true, Prepare: true),
             new("safe-w10", SafeMode: true, Requires: "Win10"), new("b")],
            [("Mine", "Normal", ["Apply a", "Apply safe-1", "Apply safe-done", "Revert safe-action", "Apply safe-action", "Apply safe-w10", "Apply b"]),
             ("Then", "Normal", ["Apply b"])],
            States: new() { ["safe-done"] = "Optimized" }),
        new("split off at the end", false, [new("a"), new("safe-1", SafeMode: true)], [("Mine", "Normal", ["Apply a", "Revert safe-1"])]),
        new("a Prepare fails", false,
            [new("a"), new("s1", "Action", SafeMode: true, Prepare: true), new("s2", "Action", SafeMode: true, Prepare: true)],
            [("Normal", "Normal", ["Apply a"]), ("Safe", "SafeMode", ["Apply s1", "Apply s2"]), ("Back", "Normal", [])],
            PrepareFails: ["s1"]),
        new("handoff", false, [new("s", SafeMode: true)], [("Safe Mode", "SafeMode", ["Apply s"]), ("Back to normal", "Normal", [])]),
        new("handoff in Safe Mode", true, [new("s", SafeMode: true)], [("Safe Mode", "SafeMode", ["Apply s"]), ("Back to normal", "Normal", [])]),
        new("handoff back to normal", false, [new("s", SafeMode: true)], [("Safe Mode", "SafeMode", ["Apply s"]), ("Back to normal", "Normal", [])], Next: 1),
        new("restarts in its last phase", false, [new("a"), new("r", "Action", Restarts: true)], [("Only", "Normal", ["Apply a", "Apply r"])]),
        new("restarts in a lone Safe Mode phase", true, [new("r", "Action", SafeMode: true, Restarts: true)], [("Only", "SafeMode", ["Apply r"])]),
        new("restart skipped", false, [new("r", "Action", Restarts: true)], [("One", "Normal", ["Apply r"]), ("Two", "Normal", [])],
            Results: new() { ["r"] = new("Skipped") }),
    ];

    /// <summary>The fakes: every step Phases takes, in order (the Oracle's step names).</summary>
    private sealed class Recorder(Scenario sc) : IRunStore, IRunBoot, IAkariLog
    {
        public List<string> Steps { get; } = [];
        public void Save(PhaseRun run) => Steps.Add($"save {run.Next}");
        public PhaseRun? Get() => null;
        public void Clear() => Steps.Add("clear");
        public void Next(string boot) => Steps.Add($"next {boot}");
        public void SafeBoot(bool on) => Steps.Add($"safeboot {(on ? "on" : "off")}");
        public void Restart(int seconds) => Steps.Add($"restart {seconds}");
        public void Write(string message) { if (!string.IsNullOrWhiteSpace(message)) Steps.Add($"log {message.TrimEnd()}"); }
        public void WriteFile(string message) => Steps.Add($"file {message}");

        public IReadOnlyList<Outcome> Plan(IReadOnlyList<PlanItem> items)
        {
            Steps.Add($"plan {string.Join(',', items.Select(i => i.Id))}");
            return items.Select(i => sc.Results?.GetValueOrDefault(i.Id) is { } r
                ? new Outcome(i.Id, i.Mode, Enum.Parse<OutcomeKind>(r.Kind), r.Reboot, r.Message)
                : new Outcome(i.Id, i.Mode, i.Mode == TweakMode.Revert ? OutcomeKind.Reverted : OutcomeKind.Applied)).ToList();
        }

        public Outcome? Prepare(Tweak t, PlanItem item)
        {
            if (!t.Has("Prepare")) return null;
            Steps.Add($"prepare {t.Id}");
            return sc.PrepareFails?.Contains(t.Id) == true ? new Outcome(t.Id, item.Mode, OutcomeKind.Failed, Message: $"no network for {t.Id}") : null;
        }
    }

    private static LoadResult Load(T[] tweaks)
    {
        var files = new MemorySourceFiles();
        foreach (var t in tweaks)
        {
            var body = t.Kind == "Action" ? "Kind = 'Action'; Apply = { 1 }" : "Registry = @( @{ Path = 'HKCU:\\Software\\Akari\\P'; Name = '" + t.Id + "'; Type = 'DWord'; Value = 0; Default = 1 } )";
            if (t.SafeMode) body += "; SafeMode = $true";
            if (t.Restarts) body += "; Restarts = $true";
            if (t.Prepare) body += "; Prepare = { 1 }";
            if (t.Requires != null) body += $"; Requires = '{t.Requires}'";
            files.Add($"src/Tweaks/Optimize/Test/{t.Id}.ps1", $$"""
                # Action: a test.
                @{ Id = '{{t.Id}}'; Name = '{{t.Id}} name'; Section = 'Optimize'; Category = 'Test'; Risk = 'Safe'; Description = 'x'
                {{body}}
                }
                """);
        }
        var loaded = new Loader(files, new Dictionary<string, ITweakCode>()).Load();
        Assert.DoesNotContain(loaded.Problems, p => p.Level == "Error");
        return loaded;
    }

    private static PhaseRun RunOf(Scenario sc) => new()
    {
        Name = sc.Name,
        Sid = "S-1-5-21-1",
        Next = sc.Next,
        Phases = sc.Phases.Select(p => new RunPhase
        {
            Name = p.Name,
            Boot = p.Boot,
            Items = p.Items.Select(i => new PlanItem(i.Split(' ')[1], Enum.Parse<TweakMode>(i.Split(' ')[0]))).ToList(),
        }).ToList(),
    };

    private static JsonObject Native(Scenario sc)
    {
        var loaded = Load(sc.Tweaks);
        var rec = new Recorder(sc);
        var run = RunOf(sc);
        var status = new Phases(new PhaseParts
        {
            Find = loaded.Find,
            State = t => Enum.Parse<TweakState>(sc.States?.GetValueOrDefault(t.Id) ?? "Default"),
            System = new FakeSystem(),
            InSafeMode = () => sc.Safe,
            Plan = rec.Plan,
            Prepare = rec.Prepare,
            Store = rec,
            Boot = rec,
            Log = rec,
        }).Start(run);
        return new JsonObject
        {
            ["Status"] = status.ToString(),
            ["Steps"] = new JsonArray([.. rec.Steps.Select(s => JsonValue.Create(s))]),
            ["Next"] = run.Next,
            ["Phases"] = new JsonArray([.. run.Phases.Select(p => new JsonObject
            {
                ["Name"] = p.Name,
                ["Boot"] = p.Boot,
                ["Items"] = new JsonArray([.. p.Items.Select(i => JsonValue.Create($"{i.Mode} {i.Id}"))]),
            })]),
            ["Outcomes"] = new JsonArray([.. run.Outcomes.Select(o => JsonValue.Create($"{o.Kind} {o.Id} {o.Mode} {o.Reboot} {o.Message}"))]),
        };
    }

    private static JsonObject ScenarioJson(Scenario sc) => new()
    {
        ["Safe"] = sc.Safe,
        ["Tweaks"] = new JsonArray([.. sc.Tweaks.Select(t => new JsonObject
        {
            ["Id"] = t.Id, ["Kind"] = t.Kind, ["SafeMode"] = t.SafeMode, ["Restarts"] = t.Restarts, ["Prepare"] = t.Prepare, ["Requires"] = t.Requires,
        })]),
        ["States"] = new JsonObject([.. (sc.States ?? []).Select(kv => KeyValuePair.Create(kv.Key, (JsonNode?)kv.Value))]),
        ["Results"] = new JsonObject([.. (sc.Results ?? []).Select(kv => KeyValuePair.Create(kv.Key,
            (JsonNode?)new JsonObject { ["Kind"] = kv.Value.Kind, ["Reboot"] = kv.Value.Reboot, ["Message"] = kv.Value.Message }))]),
        ["PrepareFails"] = new JsonArray([.. (sc.PrepareFails ?? []).Select(f => JsonValue.Create(f))]),
        ["Run"] = new JsonObject
        {
            ["Name"] = sc.Name,
            ["Next"] = sc.Next,
            ["Phases"] = new JsonArray([.. sc.Phases.Select(p => new JsonObject
            {
                ["Name"] = p.Name,
                ["Boot"] = p.Boot,
                ["Items"] = new JsonArray([.. p.Items.Select(i => new JsonObject { ["Id"] = i.Split(' ')[1], ["Mode"] = i.Split(' ')[0] })]),
            })]),
            ["Outcomes"] = new JsonArray(),
        },
    };

    [Fact]
    public void Every_scenario_runs_as_the_PowerShell_app_runs_it()
    {
        var file = Path.Combine(Path.GetTempPath(), $"akari-phases-{Guid.NewGuid():N}.json");
        File.WriteAllText(file, new JsonArray([.. Scenarios.Select(ScenarioJson)]).ToJsonString());
        JsonElement ps;
        try { ps = Oracle.Run("Export-Phases.ps1", "-Src", Repo.Src, "-Scenarios", file); }
        finally { File.Delete(file); }
        Assert.Equal(Scenarios.Length, ps.GetArrayLength());
        for (var n = 0; n < Scenarios.Length; n++)
        {
            var want = ps[n];
            var got = Native(Scenarios[n]);
            var name = Scenarios[n].Name;
            Assert.Equal((name, want.GetProperty("Status").GetString()), (name, (string?)got["Status"]));
            Assert.Equal(name + " | " + Strings(want.GetProperty("Steps")).Replace("\n", " | "), name + " | " + Strings(got["Steps"]!).Replace("\n", " | "));
            Assert.Equal((name, want.GetProperty("Next").GetInt32()), (name, (int)got["Next"]!));
            Assert.Equal((name, PhasesText(want.GetProperty("Phases"))), (name, PhasesText(JsonDocument.Parse(got["Phases"]!.ToJsonString()).RootElement)));
            Assert.Equal((name, Strings(want.GetProperty("Outcomes"))), (name, Strings(got["Outcomes"]!)));
        }
    }

    private static string PhasesText(JsonElement e) => string.Join("\n", e.EnumerateArray().Select(p =>
        $"{p.GetProperty("Name").GetString()} [{p.GetProperty("Boot").GetString()}]: {Strings(p.GetProperty("Items")).Replace('\n', ',')}"));

    private static string Strings(JsonElement e) => string.Join("\n", e.EnumerateArray().Select(x => x.GetString()));

    private static string Strings(JsonNode n) => string.Join("\n", n.AsArray().Select(x => (string?)x));
}
