using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>src/Tweaks/Hardware/Graphics/NvidiaLegacySharpen.ps1: EnableGR535 = 0 in the driver's FTS key (under
/// Parameters when the driver has that one, else nvlddmkm\FTS); Revert removes it from both.</summary>
[TweakCode("nvidia-legacy-sharpen")]
public sealed class NvidiaLegacySharpen : ITweakCode
{
    public const string Fts = @"HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS";
    public const string ParametersFts = @"HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS";
    private const string Name = "EnableGR535";

    private static string Key(TweakContext c) => c.Registry.KeyExists(ParametersFts) ? ParametersFts : Fts;

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        c.Registry.State([FileData.Row(Key(c), Name, "DWord", 0)], c.System.Build);

    public void Apply(Tweak tweak, TweakContext c, object? value) => c.Registry.SetValue(Key(c), Name, 0, "DWord");

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        c.Registry.RemoveValue(ParametersFts, Name);
        c.Registry.RemoveValue(Fts, Name);
    }
}
