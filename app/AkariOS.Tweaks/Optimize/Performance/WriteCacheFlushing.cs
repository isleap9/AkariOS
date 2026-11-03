using AkariOS.Core.Data;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>src/Tweaks/Optimize/Performance/WriteCacheFlushing.ps1: CacheIsPowerProtected = 1 in the Disk key of every
/// SCSI and NVMe disk's Device Parameters (ControlSet001\Enum). Revert removes only that value, from every Disk key.</summary>
[TweakCode("performance-write-cache-flushing-off")]
public sealed class WriteCacheFlushing : ITweakCode
{
    private const string Enum = @"HKLM:\SYSTEM\ControlSet001\Enum";
    private const string Value = "CacheIsPowerProtected";

    /// <summary>Every key under Enum\SCSI and Enum\NVME (at any depth) with this name.</summary>
    public static IReadOnlyList<string> Keys(RegistryEngine reg, string name) =>
        RegistryTree.Named(reg, [$@"{Enum}\SCSI", $@"{Enum}\NVME"], name);

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var keys = Keys(c.Registry, "Device Parameters");
        if (keys.Count == 0) return TweakState.Unknown;
        var on = keys.Count(k => c.Registry.GetValue($@"{k}\Disk", Value) is { } v && PsSemantics.LooseEquals(v, 1));
        return on == keys.Count ? TweakState.Optimized : on == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var k in Keys(c.Registry, "Device Parameters")) c.Registry.SetValue($@"{k}\Disk", Value, 1, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var k in Keys(c.Registry, "Disk")) c.Registry.RemoveValue(k, Value);
    }
}
