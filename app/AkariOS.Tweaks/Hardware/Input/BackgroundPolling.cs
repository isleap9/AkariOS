using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Input;

/// <summary>src/Tweaks/Hardware/Input/BackgroundPolling.ps1: a Choice over the raw mouse throttle (its Value block):
/// RawMouseThrottleEnabled 0 alone = Uncapped, 1 with a 20 ms duration = 50Hz, neither = Default (Windows' 125 Hz); any
/// other mix = none of its values.</summary>
[TweakCode("input-background-polling-uncapped")]
public sealed class BackgroundPolling : ITweakCode
{
    private const string Key = @"HKCU:\Control Panel\Mouse";
    private const string Enabled = "RawMouseThrottleEnabled";
    private const string Duration = "RawMouseThrottleDuration";

    public object? ChoiceValue(Tweak tweak, TweakContext c)
    {
        var on = c.Registry.GetValue(Key, Enabled);
        var ms = c.Registry.GetValue(Key, Duration);
        if (on is null && ms is null) return "Default";
        if (PsSemantics.LooseEquals(on, 0) && ms is null) return "Uncapped";
        if (PsSemantics.LooseEquals(on, 1) && PsSemantics.LooseEquals(ms, 20)) return "50Hz";
        return null;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var reg = c.Registry;
        switch (PsSemantics.Text(value))
        {
            case "Uncapped": reg.SetValue(Key, Enabled, 0, "DWord"); reg.RemoveValue(Key, Duration); break;
            case "50Hz": reg.SetValue(Key, Enabled, 1, "DWord"); reg.SetValue(Key, Duration, 20, "DWord"); break;
            case "Default": Revert(tweak, c, value); break;
            default: throw new ArgumentException($"unknown value {value}");
        }
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        c.Registry.RemoveValue(Key, Enabled);
        c.Registry.RemoveValue(Key, Duration);
    }
}
