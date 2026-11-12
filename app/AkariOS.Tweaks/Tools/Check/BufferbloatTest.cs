using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/BufferbloatTest.ps1: Waveform's bufferbloat test. An Action: it opens a web test.</summary>
[TweakCode("tools-bufferbloat-test")]
public sealed class BufferbloatTest : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "https://www.waveform.com/tools/bufferbloat");
}
