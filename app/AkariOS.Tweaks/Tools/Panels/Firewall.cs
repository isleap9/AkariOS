using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/Firewall.ps1: the classic Windows Defender Firewall panel, firewall.cpl (an Action: it opens a window).</summary>
[TweakCode("tools-panel-firewall")]
public sealed class Firewall : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "firewall.cpl");
}
