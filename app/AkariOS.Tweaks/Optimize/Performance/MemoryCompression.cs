using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>src/Tweaks/Optimize/Performance/MemoryCompression.ps1: memory compression through Windows' memory agent
/// (Get- / Disable- / Enable-MMAgent); off = Optimized.</summary>
[TweakCode("disable-memory-compression")]
public sealed class MemoryCompression : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) =>
        FileData.Need(c.Services.Memory, "memory agent").MemoryCompression ? TweakState.Default : TweakState.Optimized;

    public void Apply(Tweak tweak, TweakContext c, object? value) => FileData.Need(c.Services.Memory, "memory agent").SetMemoryCompression(false);

    public void Revert(Tweak tweak, TweakContext c, object? value) => FileData.Need(c.Services.Memory, "memory agent").SetMemoryCompression(true);
}
