using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Power;

/// <summary>src/Tweaks/Optimize/Power/PowerMode.ps1: Settings' power mode through powercfg /overlaysetactive. powercfg
/// can set the overlay but not read it, so the values Windows keeps it in are written too, and Detect reads them.</summary>
[TweakCode("power-mode-best-performance")]
public sealed class PowerMode : ITweakCode
{
    private const string Key = @"HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes";
    private const string Best = "ded574b5-45a0-4f42-8737-46345c09c238";
    private const string None = "00000000-0000-0000-0000-000000000000";
    private static readonly string[] Names = ["ActiveOverlayAcPowerScheme", "ActiveOverlayDcPowerScheme"];

    public TweakState Detect(Tweak tweak, TweakContext c) => PsSemantics.Text(c.Registry.GetValue(Key, "ActiveOverlayAcPowerScheme")) switch
    {
        var v when string.Equals(v, Best, StringComparison.OrdinalIgnoreCase) => TweakState.Optimized,
        null => TweakState.Default,
        var v when string.Equals(v, None, StringComparison.OrdinalIgnoreCase) => TweakState.Default,
        _ => TweakState.Custom,
    };

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(c, "OVERLAY_SCHEME_MAX", Best);

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(c, "OVERLAY_SCHEME_NONE", None);

    private static void Set(TweakContext c, string overlay, string scheme)
    {
        Power.Cfg(c).Run("/overlaysetactive", overlay);
        foreach (var n in Names) c.Registry.SetValue(Key, n, scheme, "String");
    }
}
