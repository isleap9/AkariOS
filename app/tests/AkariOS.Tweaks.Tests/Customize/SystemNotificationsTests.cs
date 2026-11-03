using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Customize.Notifications;
using AkariOS.Tweaks.Customize.Sound;

namespace AkariOS.Tweaks.Tests.Customize;

/// <summary>Customize's script-block Tweaks of g5 (System, Notifications, Sound, Input) on a test key and fakes. The
/// bcdedit, w32tm and registry calls of their blocks are compared with the PowerShell blocks run with recorders
/// (Oracle/Invoke-TweakBlocks.ps1); the CloudStore ones read the same test key on both sides.</summary>
public sealed class SystemNotificationsTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    private const string Current = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current";
    private const string BootUx = "bootuxdisabled          Yes";

    private static readonly Lazy<JsonElement> ToolBlocks = new(() => Oracle.Run("Invoke-TweakBlocks.ps1",
        "-Src", Repo.Src, "-Ids", "system-no-boot-ui,system-time-server", "-BcdLines", $"identifier              {{globalsettings}}|{BootUx}"));

    private JsonElement Blocks(string ids) => Oracle.Run("Invoke-TweakBlocks.ps1", "-Src", Repo.Src, "-Ids", ids, "-TestRoot", _h.KeyRoot);

    private static List<string> Lines(JsonElement e, string id, string block) =>
        e.GetProperty(id).GetProperty(block).EnumerateArray().Select(l => l.GetString()!).ToList();

    private static string Hex(object? v) => v is byte[] b ? string.Join(",", b.Select(x => x.ToString("x2"))) : PsSemantics.Text(v) ?? "";

    [Fact]
    public void Every_g5_tweak_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Customize" && t.Category is "System" or "Notifications" or "Sound" or "Input"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    // ---- the Open buttons

    [Fact]
    public void The_open_buttons_open_their_panel_or_page()
    {
        foreach (var id in new[] { "input-open-pointer-options", "sound-open-classic-panel", "system-open-date-time", "system-open-display-scaling" })
            Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Equal(["control.exe main.cpl ,2", "control.exe mmsys.cpl"], _h.Exe.Runs);
        Assert.Equal(["ms-settings:dateandtime", "ms-settings:display-advanced"], _h.Launcher.Opened);
    }

    // ---- System

    [Fact]
    public void No_boot_ui_reads_and_changes_the_boot_store_as_the_powershell_block_does()
    {
        var t = _h.Tweak("system-no-boot-ui");
        Assert.Equal(TweakState.Default, _h.State(t.Id));
        _h.Bcd.Lines = ["identifier              {globalsettings}", BootUx];
        Assert.Equal(TweakState.Optimized, _h.State(t.Id));
        var ps = ToolBlocks.Value;
        Assert.Equal(["bcd {globalsettings}", "result Optimized"], Lines(ps, t.Id, "Detect"));
        foreach (var (block, mode) in new[] { ("Apply", TweakMode.Apply), ("Revert", TweakMode.Revert) })
        {
            // the State the change starts from, so the Runner doesn't report Already
            _h.Bcd.Lines = mode == TweakMode.Apply ? [] : ["identifier              {globalsettings}", BootUx];
            _h.Bcd.Calls.Clear();
            Assert.NotEqual(OutcomeKind.Failed, _h.Run(t.Id, mode).Kind);
            // the Runner reads the State first: only the change's calls are compared
            Assert.Equal(Lines(ps, t.Id, block), _h.Bcd.Calls.Where(c => c.StartsWith("bcdedit ", StringComparison.Ordinal)));
        }
    }

    [Fact]
    public void No_boot_ui_fails_when_bcdedit_refuses()
    {
        _h.Bcd.ExitCode = 1;
        var o = _h.Run("system-no-boot-ui", TweakMode.Apply);
        Assert.Equal(OutcomeKind.Failed, o.Kind);
        Assert.Contains("bcdedit", o.Message);
    }

    [Fact]
    public void The_time_server_syncs_after_its_value_both_ways()
    {
        const string key = @"HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters";
        var ps = ToolBlocks.Value;
        Assert.Equal(OutcomeKind.Applied, _h.Run("system-time-server", TweakMode.Apply).Kind);
        Assert.Equal("0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org", _h.Get(key, "NtpServer"));
        Assert.Equal(Lines(ps, "system-time-server", "After.Apply"), _h.W32tm.Calls);
        _h.W32tm.Calls.Clear();
        Assert.Equal(OutcomeKind.Reverted, _h.Run("system-time-server", TweakMode.Revert).Kind);
        Assert.Equal("time.windows.com,0x9", _h.Get(key, "NtpServer"));
        Assert.Equal(Lines(ps, "system-time-server", "After.Revert"), _h.W32tm.Calls);
    }

    // ---- Sound

    [Fact]
    public void Loudness_eq_unhides_the_tab_on_every_playback_device_with_audio_stopped_meanwhile()
    {
        foreach (var d in new[] { "{dev-1}", "{dev-2}" }) _h.Engine.Registry.CreateKey($@"{LoudnessEQ.Render}\{d}\Properties");
        Assert.Equal(OutcomeKind.Applied, _h.Run("sound-loudness-eq-tab", TweakMode.Apply).Kind);
        foreach (var d in new[] { "{dev-1}", "{dev-2}" }) Assert.Equal(LoudnessEQ.Value, _h.Get($@"{LoudnessEQ.Render}\{d}\FxProperties", LoudnessEQ.Name));
        Assert.Equal(["stop audiosrv", "stop AudioEndpointBuilder", "start AudioEndpointBuilder", "start audiosrv"], _h.Services.Calls);
    }

    // ---- Notifications

    [Fact]
    public void Do_not_disturb_reads_and_writes_the_same_cloudstore_values_as_the_powershell_blocks()
    {
        const string account = "{0a1b2c3d-1111-2222-3333-444455556666}";
        _h.Engine.Registry.CreateKey($@"{Current}\{account}$windows.data.donotdisturb.quietmoment$quietmomentlist");
        _h.Engine.Registry.CreateKey($@"{Current}\{account}$windows.data.other$list");
        var t = _h.Tweak("notifications-no-auto-dnd");
        var ps = Blocks(t.Id);

        Assert.Equal(["default", account], AutoDoNotDisturb.Prefixes(_h.Engine.Context));
        var rows = AutoDoNotDisturb.DetectRows(t, _h.Engine.Context).Select(r => $"row {r.Path}|{r.Name}|{Hex(r.Value)}|{Hex(r.Default.For(26100))}");
        Assert.Equal(Lines(ps, t.Id, "Detect").Where(l => l.StartsWith("row ", StringComparison.Ordinal)), rows);

        Assert.Equal(TweakState.Custom, _h.State(t.Id));
        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply).Kind);
        AssertWrites(Lines(ps, t.Id, "Apply"));
        Assert.Equal(TweakState.Optimized, _h.State(t.Id));

        Assert.Equal(OutcomeKind.Reverted, _h.Run(t.Id, TweakMode.Revert).Kind);
        AssertWrites(Lines(ps, t.Id, "Revert"));
        var focus = AutoDoNotDisturb.Data(t, _h.Engine.Context).Focus.Key;
        Assert.False(_h.Engine.Registry.KeyExists($@"{AutoDoNotDisturb.Store}\{focus}"));
        Assert.Equal(TweakState.Default, _h.State(t.Id));
    }

    // every "set" the PowerShell block made holds that value in the test key now
    private void AssertWrites(IReadOnlyList<string> ps)
    {
        var sets = ps.Where(l => l.StartsWith("set ", StringComparison.Ordinal)).ToList();
        Assert.NotEmpty(sets);
        foreach (var w in sets)
        {
            var p = w[4..].Split('|');
            Assert.True(Hex(_h.Get(p[0], p[1])) == p[2], $"{p[0]}\\{p[1]}");
        }
    }

    [Fact]
    public void The_priority_list_is_emptied_for_each_account_as_the_powershell_import_does()
    {
        var t = _h.Tweak("notifications-priority-list-empty");
        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply).Kind);
        Assert.Contains(_h.Log.Lines, l => l.Contains("nothing to change", StringComparison.Ordinal));

        string[] accounts = ["{aaaa0000-1111-2222-3333-444455556666}", "{bbbb0000-1111-2222-3333-444455556666}"];
        foreach (var a in accounts)
        {
            _h.Engine.Registry.CreateKey($@"{Current}\{a}$windows.data.donotdisturb.quiethoursprofile$quiethoursprofilelist");
            _h.Engine.Registry.CreateKey($@"{Current}\{a}$windows.data.notifications$list");
        }
        Assert.Equal(accounts, PriorityNotifications.Accounts(_h.Engine.Context));
        var import = Lines(Blocks(t.Id), t.Id, "Apply").Single(l => l.StartsWith("regimport ", StringComparison.Ordinal));
        var keys = RegReader.Parse(import["regimport ".Length..]).Keys;
        Assert.Equal(accounts.Length, keys.Count);

        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply).Kind);
        foreach (var k in keys)
            foreach (var v in k.Values)
                Assert.Equal(Hex(v.Data), Hex(_h.Get(RegReader.ToTweakPath(k.Path), v.Name)));
    }
}
