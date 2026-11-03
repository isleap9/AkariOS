using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Customize.Input;

namespace AkariOS.Tweaks.Customize.Sound;

/// <summary>src/Tweaks/Customize/Sound/OpenSoundPanel.ps1: opens the classic Sound control panel, mmsys.cpl (an Action:
/// it changes nothing).</summary>
[TweakCode("sound-open-classic-panel")]
public sealed class OpenSoundPanel : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => Panel.Open(c, "mmsys.cpl");
}
