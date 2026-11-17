using System.Text.Json;
using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// winutil W4 against the PowerShell app (Oracle/Invoke-Winget.ps1: the real Uninstall-AkariApp,
/// Update-AkariWingetPackages, Get-AkariInstalledApps and Get-AkariInstalledIds over a recorder in place of
/// Invoke-AkariWinget): the same winget calls, log lines, Outcomes and lists on the same case, each side over its own
/// fake winget. Nothing real is uninstalled, updated or listed.
/// </summary>
public sealed class WingetOracleTests : IDisposable
{
    public sealed record App(string Id, string Name, string[] Winget, string Source = "", string RemoveWith = "", string Detect = "");

    public sealed record Find(string[] Lines, string[] Ids);

    public sealed record Case(Dictionary<string, int> Codes, Dictionary<string, string[]> Lines, App[] Apps, string[] Uninstall,
        bool Upgrade = false, bool Installed = false, Find? Find = null);

    private readonly TestKey _key = new();
    private readonly string _file = Path.Combine(Path.GetTempPath(), $"akari-winget-case-{Guid.NewGuid():N}.json");

    public void Dispose()
    {
        _key.Dispose();
        File.Delete(_file);
    }

    private static readonly App[] Apps =
    [
        new("two", "Two ids", ["A.One", "A.Two"]),
        new("restart", "Wants a restart", ["A.Restart"]),
        new("gone", "Not installed", ["A.Gone1", "A.Gone2"]),
        new("user", "Per user", ["A.User"]),
        new("bad", "Fails", ["A.Good", "A.Bad"]),
        new("store", "Store app", ["9TESTSTOREID"], Source: "msstore"),
        new("edge", "Own removal", ["A.Edge"], RemoveWith: "remove-edge"),
        new("file", "A download", [], Detect: "true"),
        new("nofile", "A missing download", [], Detect: "false"),
        new("broken", "A Detect that throws", [], Detect: "throw"),
        new("blind", "No Detect", []),
    ];

    private static readonly string[] Table =
    [
        "Name                Id                    Version  Source",
        "-----------------------------------------------------------",
        "One                 A.One                 2.10     winget",
        "Two                 a.two                 1.0",
        "Restart Extensions  Team.A.Restart        4.0      winget",
        "Store app           9TESTSTOREID          2.24     msstore",
        "Edge A.Edge 120 winget",
        "Gone                A.Gone1               1",
    ];

    public static TheoryData<string> Names => ["uninstall", "updated", "up to date", "update restart", "update failed", "installed", "list failed", "find"];

    private static Case Of(string name) => name switch
    {
        "uninstall" => new(
            new() { ["A.Restart"] = 3010, ["A.Gone1"] = -1978335212, ["A.Gone2"] = -1978335212, ["A.User"] = -1978335107, ["A.Bad"] = -1978335226 },
            new() { ["A.Bad"] = ["Found Bad [A.Bad]", "Uninstall failed with exit code: 1603", "  -  "] },
            Apps, Apps.Select(a => a.Id).ToArray()),
        "updated" => new([], new() { ["upgrade"] = ["Name  Id  Version  Available", "  \\  ", "Found One [A.One] Version 2", "   Successfully installed  "] }, [], [], Upgrade: true),
        "up to date" => new(new() { ["upgrade"] = -1978335189 }, new() { ["upgrade"] = ["No installed package found matching input criteria."] }, [], [], Upgrade: true),
        "update restart" => new(new() { ["upgrade"] = 1641 }, [], [], [], Upgrade: true),
        "update failed" => new(new() { ["upgrade"] = -1978335188 }, new() { ["upgrade"] = ["2 package(s) failed to upgrade.", "   "] }, [], [], Upgrade: true),
        "installed" => new([], new() { ["list"] = Table }, Apps, [], Installed: true),
        "list failed" => new(new() { ["list"] = -1978335212 }, new() { ["list"] = Table }, Apps, [], Installed: true),
        "find" => new([], [], [], [], Find: new(Table, ["A.One", "A.Two", "A.Restart", "9TESTSTOREID", "A.Edge", "A.Gone", "A.Gone1", "A.Missing", "Version"])),
        _ => throw new ArgumentException(name),
    };

    private sealed class Detects(string how) : ITweakCode
    {
        public TweakState Detect(Tweak tweak, TweakContext c) => how switch
        {
            "true" => TweakState.Optimized,
            "throw" => throw new InvalidOperationException("no"),
            _ => TweakState.Default,
        };
    }

    private sealed class NoExplorer : IExplorer
    {
        public void Restart() { }
    }

    private static string Quoted(IEnumerable<string> ids) => string.Join(", ", ids.Select(i => $"'{i}'"));

    private (List<string> Calls, List<string> Log, List<string> Outcomes, string Upgrade, List<string> Installed, List<string> Found) Native(Case c)
    {
        var winget = new FakeWingetExe
        {
            Answer = a =>
            {
                if (a[0] == "--version") return null;
                var key = a[0] == "uninstall" ? a[2] : a[0];
                return new(c.Codes.GetValueOrDefault(key), c.Lines.GetValueOrDefault(key) ?? []);
            },
        };
        var log = new MemoryLog();
        var files = new MemorySourceFiles();
        var codes = new Dictionary<string, ITweakCode>();
        foreach (var a in c.Apps)
        {
            var body = new List<string>();
            if (a.Winget.Length > 0) body.Add($"Winget = {Quoted(a.Winget)}"); else body.Add("Apply = { }");
            if (a.Source.Length > 0) body.Add($"WingetSource = '{a.Source}'");
            if (a.RemoveWith.Length > 0) body.Add($"RemoveWith = '{a.RemoveWith}'");
            if (a.Detect.Length > 0) body.Add("Detect = { 1 }");
            files.Add($"src/Tweaks/Apps/Install/{a.Id}.ps1", $$"""
                # Action: an app.
                @{ Id = '{{a.Id}}'; Name = '{{a.Name}}'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; Risk = 'Safe'; Description = 'x'
                {{string.Join("\n", body)}}
                }
                """);
            if (a.Winget.Length == 0) codes[a.Id] = new Detects(a.Detect);
        }
        var pm = new FakePackages();
        var apps = new AppPackages(pm, new FakeDism(), log);
        var tool = new Winget(winget, pm, new FakeDownloads(), apps, new RecordingExe(), log, Path.GetTempPath(), @"C:\Windows", _ => { });
        var engine = new Engine
        {
            Files = files, Registry = new RegistryEngine(_key.Paths), System = new FakeSystem(), Log = log,
            Remembered = new JsonRememberedState(Path.Combine(Path.GetTempPath(), $"akari-winget-oracle-{Guid.NewGuid():N}.json")),
            Explorer = new NoExplorer(), Presets = null!, Codes = codes, IsAdmin = () => true,
            Services = new TweakServices { Apps = apps, Winget = tool },
        };
        Assert.DoesNotContain(engine.Loaded.Problems, p => p.Level == "Error");
        var outcomes = c.Uninstall.Select(id => AppKinds.Uninstall(engine.Find(id)!, engine.Context))
            .Select(o => $"{o.Id}|{o.Kind}|{o.Reboot}|{o.Message}").ToList();
        var upgrade = "";
        if (c.Upgrade)
        {
            try { upgrade = tool.UpgradeAll().ToString(); }
            catch (InvalidOperationException e) { upgrade = $"error: {e.Message}"; }
        }
        var installed = c.Installed ? AppKinds.InstalledApps(c.Apps.Select(a => engine.Find(a.Id)!), engine.Context).ToList() : [];
        var found = c.Find is null ? [] : Winget.InstalledIds(c.Find.Lines, c.Find.Ids).ToList();
        return (winget.Calls, log.Lines.ToList(), outcomes, upgrade, installed, found);
    }

    private static List<string> Strings(JsonElement e, string name) => e.GetProperty(name).EnumerateArray().Select(x => x.GetString()!).ToList();

    [Theory, MemberData(nameof(Names))]
    public void The_same_calls_log_and_results_as_PowerShell(string name)
    {
        var c = Of(name);
        File.WriteAllText(_file, JsonSerializer.Serialize(c));
        var ps = Oracle.Run("Invoke-Winget.ps1", "-Src", Repo.Src, "-Case", _file);
        var mine = Native(c);
        Assert.Equal(Strings(ps, "Calls"), mine.Calls);
        Assert.Equal(Strings(ps, "Outcomes"), mine.Outcomes);
        Assert.Equal(ps.GetProperty("Upgrade").GetString(), mine.Upgrade);
        Assert.Equal(Strings(ps, "Installed"), mine.Installed);
        Assert.Equal(Strings(ps, "Found"), mine.Found);
        Assert.Equal(Strings(ps, "Log"), mine.Log);
    }

    [Fact]
    public void An_uninstall_tells_done_from_restart_missing_and_per_user()
    {
        var c = Of("uninstall");
        var mine = Native(c);
        Assert.Equal(
        [
            "two|Reverted|False|", "restart|Reverted|True|", "gone|Already|False|not installed",
            "user|Skipped|False|installed for this user only: uninstall it from Windows' Installed apps",
            "bad|Failed|False|winget could not uninstall A.Bad (0x8A150006): Uninstall failed with exit code: 1603",
            "store|Reverted|False|", "edge|Skipped|False|has its own removal: use Remove apps",
            "file|Skipped|False|not installed with winget: uninstall it from Windows' Installed apps",
            "nofile|Skipped|False|not installed with winget: uninstall it from Windows' Installed apps",
            "broken|Skipped|False|not installed with winget: uninstall it from Windows' Installed apps",
            "blind|Skipped|False|not installed with winget: uninstall it from Windows' Installed apps",
        ], mine.Outcomes);
        // a Tweak's ids last first, by exact id and source; the store app from msstore
        Assert.Equal("uninstall --id A.Two --exact --source winget --silent --accept-source-agreements --disable-interactivity", mine.Calls[1]);
        Assert.Equal("uninstall --id A.One --exact --source winget --silent --accept-source-agreements --disable-interactivity", mine.Calls[2]);
        Assert.Contains("uninstall --id 9TESTSTOREID --exact --source msstore --silent --accept-source-agreements --disable-interactivity", mine.Calls);
        Assert.DoesNotContain(mine.Calls, l => l.Contains("A.Edge", StringComparison.Ordinal));
    }

    [Fact]
    public void Update_all_is_one_call_and_the_installed_list_one_read()
    {
        var up = Native(Of("updated"));
        Assert.Equal(["--version", "upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"], up.Calls);
        Assert.Equal("Updated", up.Upgrade);
        Assert.Equal(["winget: updating every app", "winget: Name  Id  Version  Available", "winget: Found One [A.One] Version 2", "winget: Successfully installed"], up.Log);
        Assert.Equal("error: winget could not update every app (0x8A15002C): 2 package(s) failed to upgrade.", Native(Of("update failed")).Upgrade);

        var have = Native(Of("installed"));
        Assert.Equal(["list --accept-source-agreements --disable-interactivity"], have.Calls);
        Assert.Equal(["two", "store", "edge", "file"], have.Installed);
        Assert.Equal(["file"], Native(Of("list failed")).Installed);
        Assert.Equal(["A.One", "A.Two", "9TESTSTOREID", "A.Edge", "A.Gone1", "Version"], Native(Of("find")).Found);
    }
}
