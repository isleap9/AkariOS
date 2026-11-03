using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Advanced.Security;
using AkariOS.Tweaks.Advanced.SystemTweaks;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Advanced;

/// <summary>g9: Hardware › Input and Advanced › Security / System (not the Safe Mode ones) on a test key and fakes,
/// compared with the PowerShell blocks run with recorders (Oracle/Invoke-TweakBlocks.ps1).</summary>
public sealed class AdvancedTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    private const string Windows11Mm = "ApplicationLaunchPrefetching={0};ApplicationPreLaunch={0};OperationAPI={0};PageCombining=False;MemoryCompression=True;MaxOperationAPIFiles={1}";

    private JsonElement Blocks(string id, params string[] more) =>
        Oracle.Run("Invoke-TweakBlocks.ps1", ["-Src", Repo.Src, "-Ids", id, "-TestRoot", _h.KeyRoot, .. more]);

    [Fact]
    public void Every_g9_tweak_but_the_safe_mode_ones_is_native_now()
    {
        var batch = TweakHarness.All.Where(t => (t.Section, t.Category) is ("Hardware", "Input") or ("Advanced", "Security") or ("Advanced", "System")).ToList();
        Assert.Equal(["security-defender-off", "security-defender-settings"], batch.Where(t => t.SafeMode).Select(t => t.Id).Order());
        Assert.All(batch.Where(t => !t.SafeMode), t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));
    }

    // ---- Hardware › Input

    [Fact]
    public void Background_polling_reads_and_writes_each_of_its_values()
    {
        const string key = @"HKCU:\Control Panel\Mouse";
        var t = _h.Tweak("input-background-polling-uncapped");
        Assert.Equal("Default", _h.Engine.States.ChoiceValue(t));
        Assert.Equal(TweakState.Default, _h.State(t.Id));

        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply, "50Hz").Kind);
        Assert.Equal((1u, 20u), ((uint)_h.Get(key, "RawMouseThrottleEnabled")!, (uint)_h.Get(key, "RawMouseThrottleDuration")!));
        Assert.Equal("50Hz", _h.Engine.States.ChoiceValue(t));

        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply).Kind);
        Assert.Equal(0u, _h.Get(key, "RawMouseThrottleEnabled"));
        Assert.Null(_h.Get(key, "RawMouseThrottleDuration"));
        Assert.Equal(("Uncapped", TweakState.Optimized), (_h.Engine.States.ChoiceValue(t), _h.State(t.Id)));

        _h.Set(key, "RawMouseThrottleDuration", 8, "DWord");
        Assert.Null(_h.Engine.States.ChoiceValue(t));

        Assert.Equal(OutcomeKind.Reverted, _h.Run(t.Id, TweakMode.Revert).Kind);
        Assert.Null(_h.Get(key, "RawMouseThrottleEnabled"));
        Assert.Null(_h.Get(key, "RawMouseThrottleDuration"));
        Assert.Equal("Default", _h.Engine.States.ChoiceValue(t));
    }

    // ---- Advanced › Security

    [Fact]
    public void Dep_reads_and_changes_the_boot_entry_as_the_powershell_block_does()
    {
        const string id = "security-dep-off";
        foreach (var (nx, state) in new[] { ("", "Default"), ("OptIn", "Default"), ("AlwaysOff", "Optimized"), ("OptOut", "Custom") })
        {
            _h.Bcd.Lines = nx.Length == 0 ? ["identifier              {current}"] : ["identifier              {current}", $"nx                      {nx}"];
            var ps = Blocks(id, "-BcdLines", string.Join("|", _h.Bcd.Lines));
            Assert.Equal(state, Result(ps, id));
            Assert.Equal(state, _h.State(id).ToString());
            if (nx != "OptOut") continue;
            foreach (var (block, mode) in new[] { ("Apply", TweakMode.Apply), ("Revert", TweakMode.Revert) })
            {
                _h.Bcd.Calls.Clear();
                Assert.NotEqual(OutcomeKind.Failed, _h.Run(id, mode).Kind);
                Assert.Equal(Of(Lines(ps, id, block), "bcdedit"), _h.Bcd.Calls.Where(c => c.StartsWith("bcdedit ", StringComparison.Ordinal)));
            }
        }
        _h.Bcd.ExitCode = 1;
        Assert.Equal(OutcomeKind.Failed, _h.Run(id, TweakMode.Apply).Kind);
    }

    [Fact]
    public void Core_isolation_opens_system_information_and_windows_security()
    {
        Assert.Equal(OutcomeKind.Applied, _h.Run("security-open-core-isolation", TweakMode.Apply).Kind);
        Assert.Equal(["msinfo32.exe "], _h.Exe.Runs);
        Assert.Equal(["windowsdefender://coreisolation/"], _h.Launcher.Opened);
    }

    [Fact]
    public void Defender_tasks_turn_off_and_on_the_tasks_the_powershell_block_names()
    {
        const string id = "security-defender-tasks-off";
        var ps = Blocks(id);
        var named = Of(Lines(ps, id, "After.Apply"), "task").Select(l => l[5..].Split('|')).ToList();
        Assert.Equal(5, named.Count);
        Assert.All(named, n => Assert.Equal("False", n[2]));
        Assert.All(Of(Lines(ps, id, "After.Revert"), "task"), l => Assert.EndsWith("|True", l));
        Assert.Equal(named.Select(n => (n[0], n[1])), DefenderTasks.Tasks(_h.Tweak(id)));

        // the Task Scheduler's folders have no trailing \; a task of the same name elsewhere is left alone
        foreach (var n in named) _h.Tasks.All[new ScheduledTask(n[0].TrimEnd('\\'), n[1])] = true;
        var elsewhere = new ScheduledTask(@"\Other", named[0][1]);
        _h.Tasks.All[elsewhere] = true;

        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Equal(5, _h.Tasks.All.Count(t => !t.Value));
        Assert.True(_h.Tasks.All[elsewhere]);
        Assert.Equal(TweakState.Optimized, _h.State(id));
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        Assert.All(_h.Tasks.All.Values, Assert.True);
    }

    // ---- Advanced › System

    [Fact]
    public void Mmagent_reads_and_changes_the_memory_agent_as_the_powershell_blocks_do()
    {
        const string id = "system-mmagent-off";
        const string prefetch = @"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters";
        string Agent() => string.Format(Windows11Mm, _h.Memory.On["OperationAPI"] ? "True" : "False", _h.Memory.MaxFiles);

        _h.Set(prefetch, "EnablePrefetcher", 3, "DWord");
        var ps = Blocks(id, "-MMAgent", Agent());
        Assert.Equal(("Default", TweakState.Default), (Result(ps, id), _h.State(id)));

        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Equal(Of(Lines(ps, id, "Apply"), "mmagent"), _h.Memory.Calls);
        AssertWrites(_h, Lines(ps, id, "Apply"));
        Assert.Equal(TweakState.Optimized, _h.State(id));
        Assert.Equal("Optimized", Result(Blocks(id, "-MMAgent", Agent()), id));

        _h.Memory.Calls.Clear();
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        Assert.Equal(Of(Lines(ps, id, "Revert"), "mmagent"), _h.Memory.Calls);
        AssertWrites(_h, Lines(ps, id, "Revert"));
        Assert.Equal(TweakState.Default, _h.State(id));

        _h.Memory.MaxFiles = 256;
        Assert.Equal(("Custom", TweakState.Custom), (Result(Blocks(id, "-MMAgent", Agent()), id), _h.State(id)));
    }

    private static readonly string[] Apps =
        ["Microsoft.Windows.Search_cw5n1h2txyewy", "ShellExperienceHost_cw5n1h2txyewy", "Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy"];

    // a %SystemRoot% as Windows has it: the three app folders in SystemApps, mobsync.exe in System32
    private string Windows(string name)
    {
        var root = _h.Folder(name);
        foreach (var a in Apps) File.WriteAllText(Path.Combine(_h.Folder($@"{name}\SystemApps\{a}"), "app.txt"), a);
        File.WriteAllText(Path.Combine(_h.Folder($@"{name}\System32"), "mobsync.exe"), "");
        return root;
    }

    [Fact]
    public void Start_search_shell_moves_the_same_folders_as_the_powershell_blocks()
    {
        const string id = "system-start-search-shell-off";
        var root = Windows("Windows");
        var psRoot = Windows("WindowsPs");
        var ps = Blocks(id, "-SystemRoot", psRoot);
        Assert.Equal(("Default", TweakState.Default), (Result(ps, id), _h.State(id)));
        // the PowerShell blocks really moved the folders of their own copy: Apply, then Revert put them back
        Assert.All(Apps, a => Assert.True(Directory.Exists(Path.Combine(psRoot, "SystemApps", a))));

        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        var apply = Lines(ps, id, "Apply");
        Assert.Equal(Of(apply, "own"), Owned());
        Assert.Equal(Of(apply, "stop").Select(l => l[5..]), _h.Processes.Stopped);
        Assert.Equal(["stop WSearch"], _h.Services.Calls);
        Assert.Contains("stopservice WSearch", apply);
        AssertMoved(apply, root);
        AssertWrites(_h, apply);
        Assert.Equal(TweakState.Optimized, _h.State(id));

        _h.Exe.Runs.Clear();
        _h.Services.Calls.Clear();
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        var revert = Lines(ps, id, "Revert");
        Assert.Equal(Of(revert, "own"), Owned());
        Assert.Equal(["start WSearch"], _h.Services.Calls);
        Assert.Contains("startservice WSearch", revert);
        AssertMoved(revert, root);
        AssertWrites(_h, revert);
        Assert.Equal(TweakState.Default, _h.State(id));
        Assert.Equal("app.txt", Path.GetFileName(Directory.GetFiles(Path.Combine(root, "SystemApps", Apps[0])).Single()));
    }

    [Fact]
    public void Start_search_shell_fails_when_a_folder_stays_in_use()
    {
        var root = Windows("Windows");
        using var held = File.Open(Path.Combine(root, "System32", "mobsync.exe"), FileMode.Open, FileAccess.Read, FileShare.None);
        var o = _h.Run("system-start-search-shell-off", TweakMode.Apply);
        Assert.Equal(OutcomeKind.Failed, o.Kind);
        Assert.Contains("in use", o.Message);
        // the three folders at the first try, then five tries for mobsync.exe, each stopping the file's 21 programs
        var stop = FileData.AssignedList(_h.Engine.Files, _h.Tweak("system-start-search-shell-off").Source, "stop");
        Assert.Equal(21, stop.Count);
        Assert.Equal((3 + 5) * stop.Count, _h.Processes.Stopped.Count);
    }

    // takeown runs, as the oracle writes them ("own %SystemRoot%\…")
    private List<string> Owned()
    {
        var root = _h.Folder("Windows");
        return _h.Exe.Runs.Where(r => r.StartsWith("takeown.exe ", StringComparison.Ordinal))
            .Select(r => "own %SystemRoot%" + r.Split('"')[1][root.Length..]).ToList();
    }

    // every move the PowerShell block made is done in the C# copy: from gone, to there
    private static void AssertMoved(IReadOnlyList<string> ps, string root)
    {
        var moves = Of(ps, "move");
        Assert.Equal(4, moves.Count);
        foreach (var m in moves.Select(l => l[5..].Split('|')))
        {
            Assert.False(Exists(m[0].Replace("%SystemRoot%", root)), m[0]);
            Assert.True(Exists(m[1].Replace("%SystemRoot%", root)), m[1]);
        }
        static bool Exists(string p) => File.Exists(p) || Directory.Exists(p);
    }
}
