using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Gaming;

/// <summary>src/Tweaks/Optimize/Gaming/PresenceWriter.ps1: the presence writer's ActivationType, 0 = off, 1 = Windows'.
/// TrustedInstaller owns the key, so the value is written as TrustedInstaller (Run-Trusted there).</summary>
[TweakCode("gaming-presence-writer-off")]
public sealed class PresenceWriter : ITweakCode
{
    private const string Key = @"HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter";

    private static readonly IReadOnlyList<RegistryRow> Value = [FileData.Row(Key, "ActivationType", "DWord", 0, 1)];

    public TweakState Detect(Tweak tweak, TweakContext c) => c.Registry.GetValue(Key, "ActivationType") switch
    {
        null => TweakState.Unknown,
        var v when PsSemantics.LooseEquals(v, 0) => TweakState.Optimized,
        var v when PsSemantics.LooseEquals(v, 1) => TweakState.Default,
        _ => TweakState.Custom,
    };

    public void Apply(Tweak tweak, TweakContext c, object? value) => c.Registry.Invoke(Value, TweakMode.Apply, c.System.Build, asTrusted: true);

    public void Revert(Tweak tweak, TweakContext c, object? value) => c.Registry.Invoke(Value, TweakMode.Revert, c.System.Build, asTrusted: true);
}
