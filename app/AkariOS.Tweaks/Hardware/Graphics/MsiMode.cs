using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>src/Tweaks/Hardware/Graphics/MsiMode.ps1: MSISupported = 1 in every display adapter's
/// MessageSignaledInterruptProperties key (Enum\&lt;device&gt;); Revert removes it.</summary>
[TweakCode("graphics-msi-mode")]
public sealed class MsiMode : ITweakCode
{
    private const string Name = "MSISupported";

    public static string Key(string device) =>
        $@"HKLM:\SYSTEM\CurrentControlSet\Enum\{device}\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties";

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var v = GpuValues.Values(c, c.System.GpuDevices.Select(Key), Name);
        if (v.Count == 0) return TweakState.Unknown;
        if (v.All(x => PsSemantics.LooseEquals(x, 1))) return TweakState.Optimized;
        if (v.All(x => x is null)) return TweakState.Default;
        return TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var d in c.System.GpuDevices) c.Registry.SetValue(Key(d), Name, 1, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var d in c.System.GpuDevices) c.Registry.RemoveValue(Key(d), Name);
    }
}
