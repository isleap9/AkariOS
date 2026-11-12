using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Setup;

/// <summary>src/Tweaks/Tools/Setup/Activation.ps1: Settings › Activation. An Action: it opens a page.</summary>
[TweakCode("tools-activation")]
public sealed class Activation : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "ms-settings:activation");
}
