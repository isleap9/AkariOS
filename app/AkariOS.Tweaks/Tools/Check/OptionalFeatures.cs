using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/OptionalFeatures.ps1: Settings › Optional features. An Action: it opens a page.</summary>
[TweakCode("tools-optional-features")]
public sealed class OptionalFeatures : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "ms-settings:optionalfeatures");
}
