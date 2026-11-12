using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>A Run's parts around Phases: run.json, the next boot (RunOnce + bcdedit), the exe copy, preset Runs, the handoff.</summary>
public sealed class RunsTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-runs-{Guid.NewGuid():N}");
    private readonly TestKey _key = new();
    private readonly RegistryEngine _reg;

    public RunsTests()
    {
        Directory.CreateDirectory(_dir);
        _reg = new RegistryEngine(_key.Paths);
    }

    public void Dispose()
    {
        _key.Dispose();
        Directory.Delete(_dir, true);
    }

    private sealed class FakeBcd : IBcdEdit
    {
        public List<string> Calls { get; } = [];
        public int Code { get; set; }
        public IReadOnlyList<string> Read(string id) => [];
        public int Run(string arguments) { Calls.Add(arguments); return Code; }
    }

    private sealed class FakeShutdown : IShutdown
    {
        public int Restarts { get; private set; }
        public void Restart() => Restarts++;
    }

    private static PhaseRun Sample() => new()
    {
        Name = "AkariOS",
        Sid = "S-1-5-21-7",
        Next = 1,
        Phases =
        [
            new RunPhase { Name = "Preparation", Boot = Boot.Normal, Items = [new("install-7-zip", TweakMode.Apply)] },
            new RunPhase { Name = "Safe Mode", Boot = Boot.SafeMode, Items = [new("security-defender-settings", TweakMode.Apply), new("prio", TweakMode.Apply, 40), new("svc", TweakMode.Apply, "Manual")] },
            new RunPhase { Name = "Back", Boot = Boot.Normal },
        ],
        Outcomes = [new Outcome("install-7-zip", TweakMode.Apply, OutcomeKind.Applied), new Outcome("x", TweakMode.Revert, OutcomeKind.Failed, true, "nope")],
    };

    private static string Text(PhaseRun r) =>
        $"{r.Name}|{r.Sid}|{r.Next}|" + string.Join(";", r.Phases.Select(p => $"{p.Name}/{p.Boot}/" + string.Join(",", p.Items.Select(i => $"{i.Mode} {i.Id} {i.Value} {i.Value?.GetType().Name}"))))
        + "|" + string.Join(";", r.Outcomes);

    [Fact]
    public void Run_json_round_trips_and_clears()
    {
        var file = Path.Combine(_dir, "sub", "run.json");
        var cleared = 0;
        var store = new RunStore(file, () => cleared++);
        Assert.Null(store.Get());
        store.Save(Sample());
        Assert.Equal(Text(Sample()), Text(store.Get()!));
        store.Clear();
        Assert.False(File.Exists(file));
        Assert.Equal(1, cleared);
        File.WriteAllText(file, "{ broken");
        Assert.Null(store.Get());
    }

    [Fact]
    public void Reads_a_run_written_as_the_PowerShell_app_writes_it()
    {
        // Save-AkariRun's ConvertTo-Json: an item without Value, Outcomes as New-AkariOutcome objects
        var file = Path.Combine(_dir, "run.json");
        File.WriteAllText(file, """
            {
                "Outcomes":  [ { "Id": "a", "Mode": "Apply", "Outcome": "Applied", "Reboot": false, "Message": "" } ],
                "Next":  1, "Sid":  "S-1-5-21-7", "Name":  "AkariOS",
                "Phases":  [ { "Boot": "Normal", "Name": "One", "Items": [ { "Id": "a", "Mode": "Apply" } ] },
                             { "Boot": "SafeMode", "Name": "Two", "Items": [ { "Mode": "Apply", "Id": "b", "Value": 38 } ] } ]
            }
            """);
        var r = new RunStore(file, () => { }).Get()!;
        Assert.Equal("AkariOS|S-1-5-21-7|1|One/Normal/Apply a  ;Two/SafeMode/Apply b 38 Int32|" + new Outcome("a", TweakMode.Apply, OutcomeKind.Applied), Text(r));
    }

    [Fact]
    public void The_next_boot_is_safeboot_and_a_resume_entry()
    {
        var bcd = new FakeBcd();
        var shutdown = new FakeShutdown();
        var slept = TimeSpan.Zero;
        var boot = new RunBoot(_reg, bcd, shutdown, () => @"C:\ProgramData\AkariOS.Native\AkariOS-Native.exe", t => slept += t);

        boot.Next(Boot.SafeMode);
        Assert.Equal(["/set {current} safeboot minimal"], bcd.Calls);
        Assert.Equal(RunBoot.Command(@"C:\ProgramData\AkariOS.Native\AkariOS-Native.exe"), _reg.GetValue(RunBoot.RunOnceKey, "*!akari-native-resume"));
        Assert.Null(_reg.GetValue(RunBoot.RunOnceKey, "!akari-native-resume"));

        boot.Next(Boot.Normal);
        Assert.Equal("/deletevalue {current} safeboot", bcd.Calls[^1]);
        Assert.Null(_reg.GetValue(RunBoot.RunOnceKey, "*!akari-native-resume"));
        Assert.NotNull(_reg.GetValue(RunBoot.RunOnceKey, "!akari-native-resume"));

        boot.ClearResume();
        Assert.Null(_reg.GetValue(RunBoot.RunOnceKey, "!akari-native-resume"));

        // off when already off is fine; on that fails throws, so a phase never restarts into the wrong mode
        bcd.Code = 1;
        boot.SafeBoot(false);
        Assert.Contains("could not turn Safe Mode on", Assert.Throws<InvalidOperationException>(() => boot.SafeBoot(true)).Message);
        Assert.Null(_reg.GetValue(RunBoot.RunOnceKey, "*!akari-native-resume"));

        boot.Restart(15);
        Assert.Equal((TimeSpan.FromSeconds(15), 1), (slept, shutdown.Restarts));
    }

    [Fact]
    public void The_resume_command_asks_for_elevation_through_powershell()
    {
        Assert.Equal(
            "powershell.exe -NoProfile -WindowStyle Hidden -Command \"Start-Process -FilePath 'C:\\Users\\O''Neil\\a.exe' -ArgumentList '--resume' -Verb RunAs\"",
            RunBoot.Command(@"C:\Users\O'Neil\a.exe"));
    }

    [Fact]
    public void The_exe_is_copied_where_a_resume_finds_it()
    {
        var exe = Path.Combine(_dir, "Downloads", "AkariOS-Native.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(exe)!);
        File.WriteAllText(exe, "v1");
        var folder = Path.Combine(_dir, "ProgramData");
        var copy = Path.Combine(folder, "AkariOS-Native.exe");

        Assert.Equal(copy, new SelfCopy(exe, folder, developerBuild: false).Target());
        Assert.Equal("v1", File.ReadAllText(copy));
        File.WriteAllText(exe, "v2");
        Assert.Equal(copy, new SelfCopy(exe, folder, false).Target());
        Assert.Equal("v2", File.ReadAllText(copy));
        // running from the copy (a resume): it is the target as it is
        Assert.Equal(copy, new SelfCopy(copy, folder, false).Target());
        // a developer build isn't one file: RunOnce starts it where it is
        Assert.Equal(exe, new SelfCopy(exe, Path.Combine(_dir, "Other"), true).Target());
        Assert.False(Directory.Exists(Path.Combine(_dir, "Other")));

        // on launch: kept while a Run is saved or when running from it, else deleted
        new SelfCopy(exe, folder, false).Clean(runSaved: true);
        new SelfCopy(copy, folder, false).Clean(runSaved: false);
        Assert.True(File.Exists(copy));
        new SelfCopy(exe, folder, false).Clean(runSaved: false);
        Assert.False(File.Exists(copy));
    }

    [Fact]
    public void A_preset_run_has_its_phases_and_the_entries_on_this_pc()
    {
        var loaded = new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load();
        var preset = new PresetStore(new FolderSourceFiles(Repo.Root), _dir, Path.Combine(_dir, "lastused.json"), new MemoryLog()).Find("AkariOS")!;
        var packages = new FakePackages();
        var dism = new FakeDism();
        dism.Capabilities.Add(new DismItem("App.StepsRecorder~~~~0.0.1.0", "Installed"));
        dism.Capabilities.Add(new DismItem("Browser.InternetExplorer~~~~0.0.11.0", "NotPresent"));
        dism.Features.Add(new DismItem("WorkFolders-Client", "Enabled"));
        var apps = new AppPackages(packages, dism, new MemoryLog());

        var made = PresetRuns.Make(preset, loaded, apps, revert: false, sid: "S-1-5-21-9");
        Assert.Equal(("AkariOS", "S-1-5-21-9", 0), (made.Run.Name, made.Run.Sid, made.Run.Next));
        Assert.Equal(["Normal", "SafeMode", "Normal"], made.Run.Phases.Select(p => p.Boot));
        var debloat = made.Run.Phases[2].Items.Select(i => i.Id).ToList();
        Assert.Contains("capability/App.StepsRecorder~~~~0.0.1.0", debloat);
        Assert.Contains("feature/WorkFolders-Client", debloat);
        Assert.DoesNotContain("capability/Browser.InternetExplorer~~~~0.0.11.0", debloat);
        Assert.Empty(made.Unknown);

        var back = PresetRuns.Make(preset, loaded, apps, revert: true, sid: "");
        Assert.Single(back.Run.Phases);
        Assert.All(back.Run.Phases[0].Items, i => Assert.Equal(TweakMode.Revert, i.Mode));
    }

    [Fact]
    public void The_handoff_restarts_into_safe_mode_without_preparing_again()
    {
        var files = new MemorySourceFiles();
        files.Add("src/Tweaks/Optimize/Test/s.ps1", """
            # Action: a test.
            @{ Id = 's'; Name = 's name'; Section = 'Optimize'; Category = 'Test'; Risk = 'Safe'; Description = 'x'; Kind = 'Action'; SafeMode = $true
               Apply = { 1 }; Prepare = { 1 } }
            """);
        var loaded = new Loader(files, new Dictionary<string, ITweakCode>()).Load();
        var steps = new List<string>();
        var bcd = new FakeBcd();
        var shutdown = new FakeShutdown();
        var store = new RunStore(Path.Combine(_dir, "run.json"), () => steps.Add("clear"));
        var phases = new Phases(new PhaseParts
        {
            Find = loaded.Find,
            State = _ => TweakState.Default,
            System = new FakeSystem(),
            InSafeMode = () => false,
            Plan = items => { steps.Add("plan"); return []; },
            Prepare = (t, i) => { steps.Add($"prepare {t.Id}"); return null; },
            Store = store,
            Boot = new RunBoot(_reg, bcd, shutdown, () => @"C:\a.exe", _ => { }),
            Log = new MemoryLog(),
        });
        new SafeModeHandoff(() => phases, "S-1-5-21-3").Start([new PlanItem("s", TweakMode.Apply)]);

        Assert.Empty(steps);
        Assert.Equal(["/set {current} safeboot minimal"], bcd.Calls);
        Assert.Equal(1, shutdown.Restarts);
        var saved = store.Get()!;
        Assert.Equal(("Safe Mode", "S-1-5-21-3", 0), (saved.Name, saved.Sid, saved.Next));
        Assert.Equal(["Safe Mode/SafeMode/s", "Back to normal/Normal/"],
            saved.Phases.Select(p => $"{p.Name}/{p.Boot}/{string.Join(",", p.Items.Select(i => i.Id))}"));
    }
}
