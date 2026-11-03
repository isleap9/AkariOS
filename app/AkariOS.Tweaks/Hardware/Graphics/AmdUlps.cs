using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>src/Tweaks/Hardware/Graphics/AmdUlps.ps1: EnableUlps = 0 on every AMD adapter key, 1 on Revert.</summary>
[TweakCode("graphics-amd-ulps-off")]
public sealed class AmdUlps : ITweakCode
{
    private const string Name = "EnableUlps";

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var v = GpuValues.Read(c, "AMD", Name);
        if (v.Count == 0) return TweakState.Unknown;
        if (v.All(x => PsSemantics.LooseEquals(x, 0))) return TweakState.Optimized;
        if (v.All(x => x is null || PsSemantics.LooseEquals(x, 1))) return TweakState.Default;
        return TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Write(c, 0);

    public void Revert(Tweak tweak, TweakContext c, object? value) => Write(c, 1);

    private static void Write(TweakContext c, int v)
    {
        foreach (var g in GpuValues.Of(c, "AMD")) c.Registry.SetValue(g.Path, Name, v, "DWord");
    }
}
