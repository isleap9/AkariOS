using System.Text.Json;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Advanced.Security;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Advanced;

/// <summary>
/// The two Safe Mode Defender Toggles (N7) against their PowerShell blocks: the rows they read (Detect), the rows
/// written as TrustedInstaller and then as admin, the bcdedit calls, smartscreen.exe moved as TrustedInstaller, and the
/// values the test key holds after.
/// </summary>
public sealed class DefenderTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private string Windows => _h.Engine.Services.Windows;

    public void Dispose() => _h.Dispose();

    private JsonElement Blocks(string id) =>
        Oracle.Run("Invoke-TweakBlocks.ps1", "-Src", Repo.Src, "-Ids", id, "-TestRoot", _h.KeyRoot, "-SystemRoot", Windows);

    // as the oracle prints a row: a list (a Binary row's numbers) space-joined, as "$Value" does
    private string Row(RegistryRow r) => $"{r.Path}|{r.Name}|{Text(r.Value)}|{Text(r.Default.For(_h.Pc.Build))}";

    private static string Text(object? v) => v is object?[] list ? string.Join(" ", list.Select(Hex)) : Hex(v);

    // what the registry reads back for a row's value: a Binary list as bytes, an ExpandString expanded
    private static object? ReadBack(RegistryRow r, object? v) => v switch
    {
        object?[] list => list.Select(x => Convert.ToByte(x, System.Globalization.CultureInfo.InvariantCulture)).ToArray(),
        string s when r.Type == "ExpandString" => Environment.ExpandEnvironmentVariables(s),
        _ => v,
    };

    private string Vars(string s) => s.Replace(Windows, "%SystemRoot%", StringComparison.OrdinalIgnoreCase);

    private static List<string> Rest(List<string> lines, string kind) =>
        Of(lines, kind).Select(l => l[(l.IndexOf(' ') + 1)..]).ToList();

    // every row at its Windows default: the Toggle reads Default
    private void AtDefault(IEnumerable<RegistryRow> rows)
    {
        foreach (var r in rows)
            if (r.Default.For(_h.Pc.Build) is { } d) _h.Set(r.Path, r.Name!, d, r.Type!);
    }

    private void AssertValues(IEnumerable<RegistryRow> rows, TweakMode mode)
    {
        foreach (var r in rows)
        {
            var want = ReadBack(r, mode == TweakMode.Apply ? r.Value : r.Default.For(_h.Pc.Build));
            Assert.True(Hex(_h.Get(r.Path, r.Name!)) == Hex(want), $@"{r.Path}\{r.Name}: {Hex(_h.Get(r.Path, r.Name!))}, not {Hex(want)}");
        }
    }

    [Fact]
    public void Windows_security_settings_are_written_as_trustedinstaller_then_as_admin()
    {
        const string id = "security-defender-settings";
        var ps = Blocks(id);
        var t = _h.Tweak(id);
        var rows = DefenderSettings.Rows(t, _h.Engine.Context);
        Assert.Equal(Rest(Lines(ps, id, "Detect"), "row"), rows.Select(Row).ToList());

        AtDefault(rows);
        _h.Set(@"HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard", "EnableVirtualizationBasedSecurity", 1, "DWord");
        _h.Set(@"HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity", "ChangedInBootCycle", 1, "DWord");
        Assert.Equal(TweakState.Default, _h.State(id));

        var apply = Lines(ps, id, "Apply");
        Assert.Equal(rows.Select(r => $"Apply {Row(r)}"), Rest(apply, "trusted"));
        Assert.Equal(rows.Select(r => $"Apply {Row(r)}"), Rest(apply, "registry"));
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.True(_h.Trusted.Runs > 0);
        AssertValues(rows, TweakMode.Apply);
        AssertWrites(_h, Of(apply, "remove"));
        Assert.Equal(Of(apply, "bcdedit"), _h.Bcd.Calls);
        Assert.Equal(TweakState.Optimized, _h.State(id));

        var revert = Lines(ps, id, "Revert");
        Assert.Equal(rows.Select(r => $"Revert {Row(r)}"), Rest(revert, "trusted"));
        _h.Bcd.Calls.Clear();
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        AssertValues(rows, TweakMode.Revert);
        Assert.Equal(Of(revert, "bcdedit"), _h.Bcd.Calls);
        Assert.Equal(TweakState.Default, _h.State(id));
    }

    [Fact]
    public void Defender_off_skips_services_this_windows_lacks_and_moves_smartscreen()
    {
        const string id = "security-defender-off";
        var t = _h.Tweak(id);
        // every row's key but MDCoreSvc's (Windows 10 has none); smartscreen.exe where Windows keeps it
        var all = DefenderOff.AllRows(t, _h.Engine.Context);
        AtDefault(all.Where(r => !r.Path.EndsWith(@"\MDCoreSvc", StringComparison.Ordinal)));
        Directory.CreateDirectory(Path.Combine(Windows, "System32"));
        File.WriteAllText(Path.Combine(Windows, "System32", "smartscreen.exe"), "");

        var ps = Blocks(id);
        var rows = DefenderOff.Rows(t, _h.Engine.Context);
        Assert.DoesNotContain(rows, r => r.Path.EndsWith(@"\MDCoreSvc", StringComparison.Ordinal));
        Assert.Equal(Rest(Lines(ps, id, "Detect"), "row"), rows.Select(Row).ToList());
        Assert.Equal("Default", Result(ps, id));
        Assert.Equal(TweakState.Default, _h.State(id));

        var apply = Lines(ps, id, "Apply");
        Assert.Equal(DefenderOff.TrustedRows(rows).Select(r => $"Apply {Row(r)}"), Rest(apply, "trusted"));
        Assert.Equal(rows.Select(r => $"Apply {Row(r)}"), Rest(apply, "registry"));
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        AssertValues(rows, TweakMode.Apply);
        Assert.Equal(Rest(apply, "stop"), _h.Processes.Stopped);
        Assert.Equal(Rest(apply, "trustedrun"), _h.Trusted.Started.Select(s => Vars($"{Path.GetFileNameWithoutExtension(s.Split('|')[0])} {s.Split('|')[1]}")).ToList());

        // moved (the fake moves nothing): Optimized once it is out of System32
        File.Move(Path.Combine(Windows, "System32", "smartscreen.exe"), Path.Combine(Windows, "smartscreen.exe"));
        Assert.Equal(TweakState.Optimized, _h.State(id));
        ps = Blocks(id);
        var revert = Lines(ps, id, "Revert");
        _h.Trusted.Started.Clear();
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        AssertValues(rows, TweakMode.Revert);
        Assert.Equal(Rest(revert, "trustedrun"), _h.Trusted.Started.Select(s => Vars($"{Path.GetFileNameWithoutExtension(s.Split('|')[0])} {s.Split('|')[1]}")).ToList());
        // rows back at Default, smartscreen.exe not back yet (the fake moved nothing): Custom, as the block says
        Assert.Equal(TweakState.Custom, _h.State(id));
    }
}
