using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/PowerOptions.ps1: the classic Power Options, powercfg.cpl (an Action: it opens a window).</summary>
[TweakCode("tools-panel-power")]
public sealed class PowerOptions : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "powercfg.cpl");
}
