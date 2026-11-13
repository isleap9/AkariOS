using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/ComputerManagement.ps1: Computer Management, compmgmt.msc (an Action: it opens a window).</summary>
[TweakCode("tools-panel-computer-management")]
public sealed class ComputerManagement : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "compmgmt.msc");
}
