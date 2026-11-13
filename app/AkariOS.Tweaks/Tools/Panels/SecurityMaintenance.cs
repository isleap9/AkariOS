using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/SecurityMaintenance.ps1: Security and Maintenance, wscui.cpl (an Action: it opens a window).</summary>
[TweakCode("tools-panel-security")]
public sealed class SecurityMaintenance : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "wscui.cpl");
}
