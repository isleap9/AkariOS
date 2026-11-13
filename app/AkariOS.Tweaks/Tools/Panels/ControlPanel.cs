using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/ControlPanel.ps1: the classic Control Panel, control.exe (an Action: it opens a window).</summary>
[TweakCode("tools-panel-control")]
public sealed class ControlPanel : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "control.exe");
}
