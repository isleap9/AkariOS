using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/Region.ps1: the classic Region dialog, intl.cpl (an Action: it opens a window).</summary>
[TweakCode("tools-panel-region")]
public sealed class Region : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "intl.cpl");
}
