using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tests.Optimize;

/// <summary>Optimize's script-block Tweaks (g1: Gaming, Network, Privacy, Update) on a test key and fakes; the rows and
/// lists they build with code compared with what PowerShell evaluates (Oracle/Export-TweakRows.ps1).</summary>
public sealed class OptimizeTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    private static readonly string[] CodeRows = ["gaming-xbox-controller-no-game-bar", "update-defer-policy"];

    private static readonly Lazy<JsonElement> PowerShell = new(() =>
        Oracle.Run("Export-TweakRows.ps1", "-Src", Repo.Src, "-Ids", string.Join(",", CodeRows)));

    [Fact]
    public void Every_g1_tweak_is_native_now()
    {
        string[] ids = ["gaming-open-game-mode", "gaming-presence-writer-off", "gaming-xbox-controller-no-game-bar", "network-block-razer-asus",
            "network-ipv4-only", "privacy-app-permissions", "update-defer-policy", "update-pause-one-year", "update-prevent-os-upgrade"];
        Assert.All(ids, id => Assert.Null(Runner.NotNative(_h.Tweak(id))));
    }

    // rule 12: the real parts can't be made in a test
    [Fact]
    public void The_real_services_cant_be_made_in_a_test()
    {
        Assert.Throws<InvalidOperationException>(() => new HostsFile());
        Assert.Throws<InvalidOperationException>(() => new WmiNetBindings());
        Assert.Throws<InvalidOperationException>(() => new ShellLauncher());
        Assert.Throws<InvalidOperationException>(() => new ServiceManager());
        Assert.Throws<InvalidOperationException>(() => new AkariOS.Core.Machine.TaskScheduler());
        Assert.Throws<InvalidOperationException>(() => new ExeRunner());
        Assert.Throws<InvalidOperationException>(() => new WmiMemoryAgent());
        Assert.Throws<InvalidOperationException>(() => new WmiBitLocker());
    }

    // ---- rows built with code: the same as PowerShell's

    [Theory]
    [InlineData("gaming-xbox-controller-no-game-bar")]
    [InlineData("update-defer-policy")]
    public void Rows_built_with_code_are_the_ones_powershell_builds(string id)
    {
        var t = _h.Tweak(id);
        Assert.True(t.RowsAreCode);
        var ps = PowerShell.Value.GetProperty("Rows").GetProperty(id).EnumerateArray().Select(r =>
            $"{r.GetProperty("Path").GetString()} | {S(r, "Name")} | {S(r, "Type")} | {S(r, "Value")} | {S(r, "Default")}");
        var mine = t.Code!.Rows(t, _h.Engine.Context).Select(r =>
            $"{r.Path} | {r.Name} | {r.Type} | {PsSemantics.Text(r.Value)} | {PsSemantics.Text(r.Default.Win11)}");
        Assert.Equal(ps, mine);
    }

    private static string? S(JsonElement e, string name) => e.GetProperty(name).ValueKind == JsonValueKind.Null ? "" : e.GetProperty(name).GetString();

    [Fact]
    public void The_xbox_controller_rows_apply_and_revert()
    {
        Assert.Equal(TweakState.Default, _h.State("gaming-xbox-controller-no-game-bar"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("gaming-xbox-controller-no-game-bar", TweakMode.Apply).Kind);
        Assert.Equal(TweakState.Optimized, _h.State("gaming-xbox-controller-no-game-bar"));
        Assert.Equal(@"%SystemRoot%\System32\systray.exe", _h.Get(@"HKLM:\SOFTWARE\Classes\ms-gamebar\shell\open\command", "(default)"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("gaming-xbox-controller-no-game-bar", TweakMode.Revert).Kind);
        Assert.Equal(TweakState.Default, _h.State("gaming-xbox-controller-no-game-bar"));
        Assert.False(_h.Engine.Registry.KeyExists(@"HKLM:\SOFTWARE\Classes\ms-gamebarservices"));
    }

    [Fact]
    public void The_defer_policy_writes_its_joined_classifications()
    {
        Assert.Equal(OutcomeKind.Applied, _h.Run("update-defer-policy", TweakMode.Apply).Kind);
        var excluded = (string)_h.Get(@"HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate", "ExcludeUpdateClassifications")!;
        Assert.Equal(10, excluded.Split(';').Length);
        Assert.StartsWith("{e6cf1350-c01b-414d-a61f-263d3d4dd9f9};", excluded);
        Assert.Equal(TweakState.Optimized, _h.State("update-defer-policy"));
        _h.Run("update-defer-policy", TweakMode.Revert);
        Assert.Equal(TweakState.Default, _h.State("update-defer-policy"));
    }

    // ---- Gaming

    [Fact]
    public void Game_mode_settings_opens_its_page() => Assert.Equal(
        (OutcomeKind.Applied, "ms-settings:gaming-gamemode"),
        (_h.Run("gaming-open-game-mode", TweakMode.Apply).Kind, string.Join(",", _h.Launcher.Opened)));

    [Fact]
    public void The_presence_writer_is_written_as_trustedinstaller()
    {
        const string key = @"HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter";
        Assert.Equal(TweakState.Unknown, _h.State("gaming-presence-writer-off"));
        _h.Set(key, "ActivationType", 1, "DWord");
        Assert.Equal(TweakState.Default, _h.State("gaming-presence-writer-off"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("gaming-presence-writer-off", TweakMode.Apply).Kind);
        Assert.Equal((0u, TweakState.Optimized, 1), ((uint)_h.Get(key, "ActivationType")!, _h.State("gaming-presence-writer-off"), _h.Trusted.Runs));
        _h.Set(key, "ActivationType", 7, "DWord");
        Assert.Equal(TweakState.Custom, _h.State("gaming-presence-writer-off"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("gaming-presence-writer-off", TweakMode.Revert).Kind);
        Assert.Equal(1u, _h.Get(key, "ActivationType"));
    }

    // ---- Network

    [Fact]
    public void The_razer_asus_hosts_lines_are_the_helper_files()
    {
        var t = _h.Tweak("network-block-razer-asus");
        Assert.Equal(PowerShell.Value.GetProperty("RazerAsusHosts").EnumerateArray().Select(e => e.GetString()),
            AkariOS.Tweaks.Optimize.Network.BlockRazerAsus.Lines(t, _h.Engine.Context));
    }

    [Fact]
    public void The_razer_asus_block_is_added_and_removed_and_the_users_lines_stay()
    {
        _h.Hosts.Lines = ["# my own", "127.0.0.1 mine.local"];
        Assert.Equal(TweakState.Default, _h.State("network-block-razer-asus"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("network-block-razer-asus", TweakMode.Apply).Kind);
        Assert.Equal(TweakState.Optimized, _h.State("network-block-razer-asus"));
        Assert.Equal(["# my own", "127.0.0.1 mine.local", "# AkariOS razer-asus start"], _h.Hosts.Lines.Take(3));
        Assert.Equal("# AkariOS razer-asus end", _h.Hosts.Lines[^1]);
        Assert.Contains("0.0.0.0 id.razer.com", _h.Hosts.Lines);
        // a line taken out by hand: Custom
        _h.Hosts.Lines.Remove("0.0.0.0 id.razer.com");
        Assert.Equal(TweakState.Custom, _h.State("network-block-razer-asus"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("network-block-razer-asus", TweakMode.Revert).Kind);
        Assert.Equal(["# my own", "127.0.0.1 mine.local"], _h.Hosts.Lines);
    }

    [Fact]
    public void Hosts_blocks_replace_themselves_and_leave_others()
    {
        IReadOnlyList<string> all = ["a", "# AkariOS x start", "old", "# AkariOS x end", "b"];
        Assert.Equal(["old"], HostsBlocks.Get(all, "x"));
        Assert.Null(HostsBlocks.Get(all, "y"));
        Assert.Equal(["a", "b", "# AkariOS x start", "new", "# AkariOS x end"], HostsBlocks.Set(all, "x", ["new"]));
        Assert.Equal(["a", "b"], HostsBlocks.Set(all, "x", []));
        // an end before its start is no block
        Assert.Null(HostsBlocks.Get(["# AkariOS x end", "# AkariOS x start"], "x"));
    }

    [Fact]
    public void Ipv4_only_turns_the_bindings_off_and_back_on()
    {
        Assert.Equal(TweakState.Unknown, _h.State("network-ipv4-only"));
        _h.Bindings.On["ms_tcpip6"] = [true, true];
        _h.Bindings.On["ms_tcpip"] = [true, true];
        Assert.Equal(TweakState.Default, _h.State("network-ipv4-only"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("network-ipv4-only", TweakMode.Apply).Kind);
        Assert.Equal(TweakState.Optimized, _h.State("network-ipv4-only"));
        Assert.Equal(["-ms_lldp", "-ms_lltdio", "-ms_implat", "-ms_rspndr", "-ms_tcpip6", "-ms_server", "-ms_msclient", "-ms_pacer"], _h.Bindings.Calls);
        // IPv4 itself stays on
        Assert.Equal([true, true], _h.Bindings.On["ms_tcpip"]);
        _h.Bindings.On["ms_tcpip6"][0] = true;
        Assert.Equal(TweakState.Custom, _h.State("network-ipv4-only"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("network-ipv4-only", TweakMode.Revert).Kind);
        Assert.Contains("+ms_tcpip", _h.Bindings.Calls);
        Assert.Equal(TweakState.Default, _h.State("network-ipv4-only"));
    }

    // ---- Privacy

    [Fact]
    public void App_permissions_reset_windows_copy_both_ways()
    {
        var dir = Path.Combine(_h.Dir, "ProgramData", "Microsoft", "Windows", "CapabilityAccessManager");
        Directory.CreateDirectory(dir);
        foreach (var f in new[] { "CapabilityConsentStorage.db", "CapabilityConsentStorage.db-wal", "other.db" }) File.WriteAllText(Path.Combine(dir, f), "");
        Assert.Equal(OutcomeKind.Applied, _h.Run("privacy-app-permissions", TweakMode.Apply).Kind);
        Assert.Equal("Deny", _h.Get(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts", "Value"));
        Assert.Equal(["camsvc"], _h.Services.Stopped);
        Assert.Equal(["other.db"], Directory.GetFiles(dir).Select(Path.GetFileName));
        Assert.Equal(1, _h.Trusted.Runs);
        Assert.Equal(OutcomeKind.Reverted, _h.Run("privacy-app-permissions", TweakMode.Revert).Kind);
        Assert.Equal((2, "Allow"), (_h.Services.Stopped.Count, (string?)_h.Get(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts", "Value")));
    }

    // ---- Update

    [Fact]
    public void Pausing_updates_writes_a_year_from_now_and_ends_on_its_own()
    {
        const string key = @"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings";
        Assert.Equal(TweakState.Default, _h.State("update-pause-one-year"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("update-pause-one-year", TweakMode.Apply).Kind);
        Assert.Equal(("2027-11-03T12:00:00Z", "2026-11-03T12:00:00Z"), ((string)_h.Get(key, "PauseQualityUpdatesEndTime")!, (string)_h.Get(key, "PauseUpdatesStartTime")!));
        Assert.Equal(TweakState.Optimized, _h.State("update-pause-one-year"));
        // a year and a day later the pause is over
        _h.Now = _h.Now.AddDays(366);
        Assert.Equal(TweakState.Default, _h.State("update-pause-one-year"));
        _h.Set(key, "PauseUpdatesExpiryTime", "not a date", "String");
        Assert.Equal(TweakState.Custom, _h.State("update-pause-one-year"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("update-pause-one-year", TweakMode.Revert).Kind);
        Assert.Null(_h.Get(key, "PauseUpdatesExpiryTime"));
        Assert.Null(_h.Get(key, "PauseFeatureUpdatesStartTime"));
    }

    [Fact]
    public void Staying_on_this_version_holds_this_pcs_windows_and_version()
    {
        const string key = @"HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate";
        Assert.Equal(TweakState.Default, _h.State("update-prevent-os-upgrade"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("update-prevent-os-upgrade", TweakMode.Apply).Kind);
        Assert.Equal(("Windows 11", 1u, "24H2"), ((string)_h.Get(key, "ProductVersion")!, (uint)_h.Get(key, "TargetReleaseVersion")!, (string)_h.Get(key, "TargetReleaseVersionInfo")!));
        Assert.Equal(TweakState.Optimized, _h.State("update-prevent-os-upgrade"));
        _h.Engine.Registry.RemoveValue(key, "ProductVersion");
        Assert.Equal(TweakState.Custom, _h.State("update-prevent-os-upgrade"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("update-prevent-os-upgrade", TweakMode.Revert).Kind);
        Assert.Equal(TweakState.Default, _h.State("update-prevent-os-upgrade"));

        // Windows 10, and a Windows that doesn't say its version: Failed, nothing written
        _h.Pc.Build = 19045;
        _h.Pc.Edition = "Professional";
        _h.Run("update-prevent-os-upgrade", TweakMode.Apply);
        Assert.Equal("Windows 10", _h.Get(key, "ProductVersion"));
        _h.Run("update-prevent-os-upgrade", TweakMode.Revert);
        _h.Pc.DisplayVersion = null;
        var o = _h.Run("update-prevent-os-upgrade", TweakMode.Apply);
        Assert.Equal((OutcomeKind.Failed, (object?)null), (o.Kind, _h.Get(key, "ProductVersion")));
        Assert.Contains("does not say its version", o.Message);
    }
}
