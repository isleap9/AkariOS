using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>src/Tweaks/Hardware/Graphics/Hdcp.ps1: RMHdcpKeyglobZero = 1 on every NVIDIA adapter key; Revert removes
/// it.</summary>
[TweakCode("graphics-hdcp-off")]
public sealed class Hdcp : ITweakCode
{
    private const string Name = "RMHdcpKeyglobZero";

    public TweakState Detect(Tweak tweak, TweakContext c) => GpuValues.OneOrAbsent(GpuValues.Read(c, "NVIDIA", Name));

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var g in GpuValues.Of(c, "NVIDIA")) c.Registry.SetValue(g.Path, Name, 1, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var g in GpuValues.Of(c, "NVIDIA")) c.Registry.RemoveValue(g.Path, Name);
    }
}
