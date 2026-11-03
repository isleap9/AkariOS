using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.SystemTweaks; // not .System: it would hide .NET's System namespace

/// <summary>src/Tweaks/Customize/System/OpenDateTime.ps1: opens Settings › Time &amp; language › Date &amp; time (an Action:
/// it changes nothing).</summary>
[TweakCode("system-open-date-time")]
public sealed class OpenDateTime : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        FileData.Need(c.Services.Launcher, "Settings launcher").Open("ms-settings:dateandtime");
}
