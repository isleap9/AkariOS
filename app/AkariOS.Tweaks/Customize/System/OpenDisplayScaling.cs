using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.SystemTweaks; // not .System: it would hide .NET's System namespace

/// <summary>src/Tweaks/Customize/System/OpenDisplayScaling.ps1: opens Settings › Display › Advanced display (an Action:
/// it changes nothing).</summary>
[TweakCode("system-open-display-scaling")]
public sealed class OpenDisplayScaling : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        FileData.Need(c.Services.Launcher, "Settings launcher").Open("ms-settings:display-advanced");
}
