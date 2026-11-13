using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/DateTime.ps1: the classic Date and Time dialog, timedate.cpl (an Action: it opens a window).</summary>
[TweakCode("tools-panel-date-time")]
public sealed class DateTime : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "timedate.cpl");
}
