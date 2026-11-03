using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>src/Tweaks/Hardware/Graphics/IntelSettings.ps1: Global_AsyncFlipMode = 2 and Global_LowLatency = 1 in every
/// Intel adapter's 3DKeys subkey; Revert deletes that subkey.</summary>
[TweakCode("graphics-intel-settings")]
public sealed class IntelSettings : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var s = GpuValues.Of(c, "Intel").Select(g =>
        {
            var a = c.Registry.GetValue($@"{g.Path}\3DKeys", "Global_AsyncFlipMode");
            var l = c.Registry.GetValue($@"{g.Path}\3DKeys", "Global_LowLatency");
            return PsSemantics.LooseEquals(a, 2) && PsSemantics.LooseEquals(l, 1) ? TweakState.Optimized
                : a is null && l is null ? TweakState.Default : TweakState.Custom;
        }).ToList();
        if (s.Count == 0) return TweakState.Unknown;
        return s.Distinct().Count() == 1 ? s[0] : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var g in GpuValues.Of(c, "Intel"))
        {
            c.Registry.SetValue($@"{g.Path}\3DKeys", "Global_AsyncFlipMode", 2, "DWord");
            c.Registry.SetValue($@"{g.Path}\3DKeys", "Global_LowLatency", 1, "DWord");
        }
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var g in GpuValues.Of(c, "Intel")) c.Registry.DeleteKey($@"{g.Path}\3DKeys");
    }
}
