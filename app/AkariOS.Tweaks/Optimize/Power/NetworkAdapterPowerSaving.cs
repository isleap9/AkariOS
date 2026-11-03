using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Power;

/// <summary>src/Tweaks/Optimize/Power/NetworkAdapterPowerSaving.ps1: every network adapter's driver key (the network
/// class's 0000, 0001…): PnPCapabilities 24 and the power saving / wake settings "0". The setting names are the file's
/// ($text on Apply, $names on Revert), read from it.</summary>
[TweakCode("power-network-adapter-power-saving-off")]
public sealed partial class NetworkAdapterPowerSaving : ITweakCode
{
    private const string Class = @"HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}";

    [GeneratedRegex(@"^\d{4}$")]
    private static partial Regex Adapter();

    private static IReadOnlyList<string> Keys(TweakContext c) =>
        c.Registry.SubKeys(Class).Where(k => Adapter().IsMatch(k)).Select(k => $@"{Class}\{k}").ToList();

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var keys = Keys(c);
        if (keys.Count == 0) return TweakState.Unknown;
        var off = keys.Count(k => c.Registry.GetValue(k, "PnPCapabilities") is { } v && PsSemantics.LooseEquals(v, 24));
        return off == keys.Count ? TweakState.Optimized : off == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var text = FileData.AssignedList(c.Files, tweak.Source, "text");
        foreach (var k in Keys(c))
        {
            RegistryTree.Try(() => c.Registry.SetValue(k, "PnPCapabilities", 24, "DWord"));
            foreach (var n in text) RegistryTree.Try(() => c.Registry.SetValue(k, n, "0", "String"));
        }
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var names = FileData.AssignedList(c.Files, tweak.Source, "names");
        foreach (var k in Keys(c))
            foreach (var n in names) RegistryTree.Try(() => c.Registry.RemoveValue(k, n));
    }
}
