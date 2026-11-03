using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>What the per-GPU blocks share: a vendor's adapter keys (Get-AkariGpus | Where-Object Vendor -eq …), one
/// value read from each, and the Detect of the Tweaks that write 1 and remove it on Revert.</summary>
public static class GpuValues
{
    public static IReadOnlyList<Gpu> Of(TweakContext c, string vendor) => c.System.Gpus.Where(g => g.Vendor == vendor).ToList();

    /// <summary>The value on each of the vendor's adapters, in the adapters' order.</summary>
    public static IReadOnlyList<object?> Read(TweakContext c, string vendor, string name) => Values(c, Of(c, vendor).Select(g => g.Path), name);

    /// <summary>
    /// The value in each key, as `@(… | ForEach-Object { Get-AkariRegValue $key $name })` collects it: null where the
    /// value is missing, nothing where the whole key is (Get-AkariRegValue outputs nothing then).
    /// </summary>
    public static IReadOnlyList<object?> Values(TweakContext c, IEnumerable<string> keys, string name) =>
        keys.Where(c.Registry.KeyExists).Select(k => c.Registry.GetValue(k, name)).ToList();

    /// <summary>HDCP and P0 state: no adapter = Unknown; 1 everywhere = Optimized; missing or 0 everywhere = Default.</summary>
    public static TweakState OneOrAbsent(IReadOnlyList<object?> v)
    {
        if (v.Count == 0) return TweakState.Unknown;
        if (v.All(x => PsSemantics.LooseEquals(x, 1))) return TweakState.Optimized;
        if (v.All(x => !PsSemantics.Truthy(x) || PsSemantics.LooseEquals(x, 0))) return TweakState.Default;
        return TweakState.Custom;
    }
}
