using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/SystemProperties.ps1: System Properties, sysdm.cpl (an Action: it opens a window).</summary>
[TweakCode("tools-panel-system")]
public sealed class SystemProperties : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "sysdm.cpl");
}
