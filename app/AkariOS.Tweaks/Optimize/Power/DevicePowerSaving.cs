using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Power;

/// <summary>src/Tweaks/Optimize/Power/DevicePowerSaving.ps1: every ACPI, HID, PCI and USB device's Device Parameters
/// (power saving, selective suspend, wake) and WDF (idle) values. A key that refuses the change is skipped. Revert also
/// removes the old script's misspelt SeleactiveSuspendEnabled.</summary>
[TweakCode("power-device-power-saving-off")]
public sealed class DevicePowerSaving : ITweakCode
{
    private const string Enum = @"HKLM:\SYSTEM\ControlSet001\Enum";
    private static readonly string[] Roots = [$@"{Enum}\ACPI", $@"{Enum}\HID", $@"{Enum}\PCI", $@"{Enum}\USB"];
    private static readonly string[] Parameters = ["EnhancedPowerManagementEnabled", "SelectiveSuspendEnabled", "SeleactiveSuspendEnabled", "SelectiveSuspendOn", "WaitWakeEnabled"];

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var keys = RegistryTree.Named(c.Registry, Roots, "Device Parameters");
        if (keys.Count == 0) return TweakState.Unknown;
        var off = keys.Count(k => c.Registry.GetValue(k, "WaitWakeEnabled") is { } v && PsSemantics.LooseEquals(v, 0));
        return off == keys.Count ? TweakState.Optimized : off == 0 ? TweakState.Default : TweakState.Custom;
    }

    private static IReadOnlyList<string> Keys(TweakContext c) =>
        RegistryTree.Find(c.Registry, Roots, k => k.Equals("Device Parameters", StringComparison.OrdinalIgnoreCase) || k.Equals("WDF", StringComparison.OrdinalIgnoreCase));

    private static bool IsWdf(string key) => key.EndsWith(@"\WDF", StringComparison.OrdinalIgnoreCase);

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var k in Keys(c))
        {
            if (IsWdf(k)) { RegistryTree.Try(() => c.Registry.SetValue(k, "IdleInWorkingState", 0, "DWord")); continue; }
            RegistryTree.Try(() => c.Registry.SetValue(k, "EnhancedPowerManagementEnabled", 0, "DWord"));
            RegistryTree.Try(() => c.Registry.SetValue(k, "SelectiveSuspendEnabled", new byte[] { 0 }, "Binary"));
            RegistryTree.Try(() => c.Registry.SetValue(k, "SelectiveSuspendOn", 0, "DWord"));
            RegistryTree.Try(() => c.Registry.SetValue(k, "WaitWakeEnabled", 0, "DWord"));
        }
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var k in Keys(c))
            foreach (var n in IsWdf(k) ? ["IdleInWorkingState"] : Parameters)
                RegistryTree.Try(() => c.Registry.RemoveValue(k, n));
    }
}
