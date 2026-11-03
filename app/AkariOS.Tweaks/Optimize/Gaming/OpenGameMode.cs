using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Gaming;

/// <summary>src/Tweaks/Optimize/Gaming/OpenGameMode.ps1: opens Settings › Gaming › Game Mode (an Action: it changes
/// nothing).</summary>
[TweakCode("gaming-open-game-mode")]
public sealed class OpenGameMode : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        FileData.Need(c.Services.Launcher, "Settings launcher").Open("ms-settings:gaming-gamemode");
}
