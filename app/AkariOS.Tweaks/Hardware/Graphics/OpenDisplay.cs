using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>src/Tweaks/Hardware/Graphics/OpenDisplay.ps1: opens Settings › Display (an Action: it changes nothing).</summary>
[TweakCode("graphics-open-display")]
public sealed class OpenDisplay : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        FileData.Need(c.Services.Launcher, "Settings launcher").Open("ms-settings:display");
}
