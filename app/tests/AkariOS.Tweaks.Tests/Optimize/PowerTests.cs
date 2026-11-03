using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tests.Optimize;

/// <summary>Optimize › Power's script-block Tweaks (g3) on a test key and a powercfg fake. The powercfg calls and
/// registry writes of every Apply and Revert are compared with the PowerShell blocks' (Oracle/Invoke-TweakBlocks.ps1
/// runs them with recorders in place of powercfg and the registry).</summary>
public sealed class PowerTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    private const string Other = "a1841308-3541-4fab-bc81-f71556f20b4a";
    private static readonly string[] PowerCfgTweaks = ["power-hibernate-off", "power-mode-best-performance", "power-no-sign-in-after-sleep", "power-ultimate-plan"];

    private static readonly Lazy<JsonElement> PowerShell = new(() => Oracle.Run("Invoke-TweakBlocks.ps1",
        "-Src", Repo.Src, "-Ids", string.Join(",", PowerCfgTweaks), "-PlanList", $"381b4222-f694-41f0-9685-ff5bb260df2e,{UltimatePlanGuid},{Other}"));

    private const string UltimatePlanGuid = "99999999-9999-9999-9999-999999999999";

    [Fact]
    public void Every_power_tweak_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Optimize" && t.Category == "Power"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    public static TheoryData<string> PowerCfgIds => [.. PowerCfgTweaks];

    // the blocks' calls in order: powercfg exactly; each registry write as the value the test key holds after
    [Theory, MemberData(nameof(PowerCfgIds))]
    public void The_same_powercfg_calls_and_registry_writes_as_the_powershell_blocks(string id)
    {
        // what powercfg /list prints, as the oracle answers it
        _h.PowerCfg.Answer = a => a[0] == "/list"
            ? [$"Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Plan)", $"Power Scheme GUID: {UltimatePlanGuid}  (Plan)", $"Power Scheme GUID: {Other}  (Plan)"]
            : [];
        var t = _h.Tweak(id);
        foreach (var (block, mode) in new[] { ("Apply", TweakMode.Apply), ("Revert", TweakMode.Revert) })
        {
            var ps = PowerShell.Value.GetProperty(id).GetProperty(block).EnumerateArray().Select(e => e.GetString()!).ToList();
            _h.PowerCfg.Calls.Clear();
            if (mode == TweakMode.Apply) t.Code!.Apply(t, _h.Engine.Context, null); else t.Code!.Revert(t, _h.Engine.Context, null);
            Assert.Equal(ps.Where(l => l.StartsWith("powercfg ", StringComparison.Ordinal)), _h.PowerCfg.Calls);
            foreach (var w in ps.Where(l => !l.StartsWith("powercfg ", StringComparison.Ordinal)))
            {
                var parts = w[(w.IndexOf(' ') + 1)..].Split('|');
                var now = PsSemantics.Text(_h.Get(parts[0], parts[1]));
                Assert.True(w.StartsWith("remove ", StringComparison.Ordinal) ? now is null : now == parts[2], $"{id} {block}: {w} -> {now ?? "(none)"}");
            }
        }
    }

    [Fact]
    public void The_ultimate_plan_reads_its_lists_out_of_the_file()
    {
        var t = _h.Tweak("power-ultimate-plan");
        Assert.Equal(36, Tweaks.Optimize.Power.UltimatePlan.Tuned(t).Count);
        Assert.Equal(4, Tweaks.Optimize.Power.UltimatePlan.HiddenSettings(t).Count);
        Assert.Equal(["chrome.exe", "Discord.exe"], Tweaks.Optimize.Power.UltimatePlan.Overridden(t));
    }

    [Theory]
    [InlineData("Power Scheme GUID: 99999999-9999-9999-9999-999999999999  (Ultimate Performance)", TweakState.Optimized)]
    [InlineData("Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)", TweakState.Default)]
    [InlineData("Power Scheme GUID: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  (High performance)", TweakState.Custom)]
    public void The_ultimate_plan_is_read_from_the_active_scheme(string line, TweakState state)
    {
        _h.PowerCfg.Answer = a => a[0] == "/getactivescheme" ? [line] : [];
        Assert.Equal(state, _h.State("power-ultimate-plan"));
    }

    [Theory]
    [InlineData(new[] { "    Current AC Power Setting Index: 0x00000000", "    Current DC Power Setting Index: 0x00000000" }, TweakState.Optimized)]
    [InlineData(new[] { "  Possible Setting Index: 001", "  Indice impostazione corrente CA: 0x00000001", "  Indice impostazione corrente CC: 0x00000001" }, TweakState.Default)]
    [InlineData(new[] { "AC: 0x00000000", "DC: 0x00000001" }, TweakState.Custom)]
    [InlineData(new[] { "The power scheme, subgroup or setting specified does not exist." }, TweakState.Unknown)]
    public void Sign_in_after_sleep_is_read_from_powercfg_in_any_language(string[] lines, TweakState state)
    {
        _h.PowerCfg.Answer = a => a[0] == "/qh" ? lines : [];
        Assert.Equal(state, _h.State("power-no-sign-in-after-sleep"));
    }

    [Fact]
    public void Hibernate_and_power_mode_states_come_from_their_values()
    {
        Assert.Equal((TweakState.Default, TweakState.Default), (_h.State("power-hibernate-off"), _h.State("power-mode-best-performance")));
        _h.Run("power-hibernate-off", TweakMode.Apply);
        _h.Run("power-mode-best-performance", TweakMode.Apply);
        Assert.Equal((TweakState.Optimized, TweakState.Optimized), (_h.State("power-hibernate-off"), _h.State("power-mode-best-performance")));
        _h.Set(@"HKLM:\SYSTEM\CurrentControlSet\Control\Power", "HibernateEnabled", 5, "DWord");
        _h.Set(@"HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes", "ActiveOverlayAcPowerScheme", "961cc777-2547-4f9d-8174-7d86181b8a7a", "String");
        Assert.Equal((TweakState.Custom, TweakState.Custom), (_h.State("power-hibernate-off"), _h.State("power-mode-best-performance")));
    }

    [Fact]
    public void Device_power_saving_goes_off_on_every_device_and_comes_back()
    {
        const string e = @"HKLM:\SYSTEM\ControlSet001\Enum";
        Assert.Equal(TweakState.Unknown, _h.State("power-device-power-saving-off"));
        _h.Set($@"{e}\USB\VID_1\1\Device Parameters", "Other", 1, "DWord");
        _h.Set($@"{e}\HID\VID_2\2\Device Parameters\WDF", "Other", 1, "DWord");
        _h.Set($@"{e}\ACPI\PNP0A08\0\Device Parameters", "SeleactiveSuspendEnabled", new byte[] { 1 }, "Binary");
        Assert.Equal(TweakState.Default, _h.State("power-device-power-saving-off"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("power-device-power-saving-off", TweakMode.Apply).Kind);
        Assert.Equal(TweakState.Optimized, _h.State("power-device-power-saving-off"));
        Assert.Equal(new byte[] { 0 }, _h.Get($@"{e}\USB\VID_1\1\Device Parameters", "SelectiveSuspendEnabled"));
        Assert.Equal(0u, _h.Get($@"{e}\HID\VID_2\2\Device Parameters\WDF", "IdleInWorkingState"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("power-device-power-saving-off", TweakMode.Revert).Kind);
        Assert.Equal(TweakState.Default, _h.State("power-device-power-saving-off"));
        Assert.Null(_h.Get($@"{e}\ACPI\PNP0A08\0\Device Parameters", "SeleactiveSuspendEnabled"));
        Assert.Null(_h.Get($@"{e}\HID\VID_2\2\Device Parameters\WDF", "IdleInWorkingState"));
        Assert.Equal(1u, _h.Get($@"{e}\USB\VID_1\1\Device Parameters", "Other"));
    }

    [Fact]
    public void Network_adapters_lose_power_saving_and_wake_with_the_files_names()
    {
        const string cls = @"HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}";
        Assert.Equal(TweakState.Unknown, _h.State("power-network-adapter-power-saving-off"));
        _h.Set($@"{cls}\0000", "DriverDesc", "Ethernet", "String");
        _h.Set($@"{cls}\Properties", "x", 1, "DWord");
        Assert.Equal(TweakState.Default, _h.State("power-network-adapter-power-saving-off"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("power-network-adapter-power-saving-off", TweakMode.Apply).Kind);
        Assert.Equal((24u, "0", "0"), ((uint)_h.Get($@"{cls}\0000", "PnPCapabilities")!, (string)_h.Get($@"{cls}\0000", "*EEE")!, (string)_h.Get($@"{cls}\0000", "WakeOnLink")!));
        Assert.Null(_h.Get($@"{cls}\Properties", "PnPCapabilities"));
        Assert.Equal(TweakState.Optimized, _h.State("power-network-adapter-power-saving-off"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("power-network-adapter-power-saving-off", TweakMode.Revert).Kind);
        Assert.Equal(((object?)null, (object?)null, "Ethernet"), (_h.Get($@"{cls}\0000", "PnPCapabilities"), _h.Get($@"{cls}\0000", "*EEE"), (string?)_h.Get($@"{cls}\0000", "DriverDesc")));
    }

    [Fact]
    public void The_real_powercfg_cant_be_made_in_a_test() => Assert.Throws<InvalidOperationException>(() => new PowerCfg());
}
