using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Power;

/// <summary>
/// src/Tweaks/Optimize/Power/UltimatePlan.ps1: the Ultimate Performance plan as 99999999-…, active, every other plan
/// deleted, its settings tuned (AC and DC), four hidden settings shown, Chrome and Discord kept from holding the screen
/// on. Revert = Windows' default plans. The settings, the hidden settings and the processes are read out of the file's
/// Apply block (the PowerShell app's own list), not copied.
/// </summary>
[TweakCode("power-ultimate-plan")]
public sealed partial class UltimatePlan : ITweakCode
{
    public const string Plan = "99999999-9999-9999-9999-999999999999";
    private const string Ultimate = "e9a42b02-d5df-448d-aa00-03f14749eb61";
    private const string Balanced = "381b4222-f694-41f0-9685-ff5bb260df2e";
    private const string Settings = @"HKLM:\SYSTEM\ControlSet001\Control\Power\PowerSettings";
    private const string Guid = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";

    [GeneratedRegex(Guid, RegexOptions.IgnoreCase)]
    private static partial Regex AnyGuid();

    [GeneratedRegex(@",@\('(" + Guid + @")',\s*'(" + Guid + @")',\s*(\d+)\)", RegexOptions.IgnoreCase)]
    private static partial Regex SettingLine();

    [GeneratedRegex(@"'(" + Guid + @"\\" + Guid + @")'", RegexOptions.IgnoreCase)]
    private static partial Regex HiddenKey();

    [GeneratedRegex(@"foreach \(\$x in ((?:'[^']+'(?:,\s*)?)+)\)")]
    private static partial Regex Processes();

    private static string Block(Tweak t, string name) => (t.Fields.Get(name) as PsScriptBlock)?.Text ?? throw new InvalidOperationException($"{t.Source} has no {name} block");

    /// <summary>The plan's settings: subgroup, setting, value.</summary>
    public static IReadOnlyList<(string Group, string Setting, string Value)> Tuned(Tweak t) =>
        SettingLine().Matches(Block(t, "Apply")).Select(m => (m.Groups[1].Value, m.Groups[2].Value, m.Groups[3].Value)).ToList();

    /// <summary>The settings Power Options hides, shown so they can be set (subgroup\setting).</summary>
    public static IReadOnlyList<string> HiddenSettings(Tweak t) =>
        HiddenKey().Matches(Block(t, "Apply")).Select(m => m.Groups[1].Value).Distinct().ToList();

    /// <summary>The processes kept from holding the screen on.</summary>
    public static IReadOnlyList<string> Overridden(Tweak t) =>
        Processes().Match(Block(t, "Apply")) is { Success: true } m
            ? PsSemantics.AsList(PsData.ParseValue(m.Groups[1].Value)).Select(v => PsSemantics.Text(v)!).ToList()
            : throw new InvalidOperationException($"{t.Source}: no processes");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var active = string.Join(" ", Power.Cfg(c).Run("/getactivescheme"));
        if (active.Contains(Plan, StringComparison.OrdinalIgnoreCase)) return TweakState.Optimized;
        return active.Contains(Balanced, StringComparison.OrdinalIgnoreCase) ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var cfg = Power.Cfg(c);
        cfg.Run("/duplicatescheme", Ultimate, Plan);
        cfg.Run("/setactive", Plan);
        // every other plan goes (the GUID before the name on each line of /list, whatever the language)
        foreach (var line in cfg.Run("/list"))
            if (AnyGuid().Match(line) is { Success: true } g && !g.Value.Equals(Plan, StringComparison.OrdinalIgnoreCase)) cfg.Run("/delete", g.Value);
        foreach (var k in HiddenSettings(tweak)) c.Registry.SetValue($@"{Settings}\{k}", "Attributes", 0, "DWord");
        foreach (var (group, setting, v) in Tuned(tweak))
        {
            cfg.Run("/setacvalueindex", Plan, group, setting, v);
            cfg.Run("/setdcvalueindex", Plan, group, setting, v);
        }
        foreach (var x in Overridden(tweak)) cfg.Run("/requestsoverride", "PROCESS", x, "DISPLAY", "SYSTEM", "AWAYMODE");
        cfg.Run("/setactive", Plan);
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var cfg = Power.Cfg(c);
        cfg.Run("/restoredefaultschemes");
        foreach (var x in Overridden(tweak)) cfg.Run("/requestsoverride", "PROCESS", x);
        foreach (var k in HiddenSettings(tweak)) c.Registry.SetValue($@"{Settings}\{k}", "Attributes", 1, "DWord");
    }
}
