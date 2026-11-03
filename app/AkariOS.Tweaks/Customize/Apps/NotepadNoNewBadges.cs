using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>src/Tweaks/Customize/Apps/NotepadNoNewBadges.ps1: GenerateNewBadgeLifetime in Notepad's settings hive;
/// Revert deletes it.</summary>
[TweakCode("apps-notepad-no-new-badges")]
public sealed class NotepadNoNewBadges : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => AppHive.State(tweak, c);

    public void Apply(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Apply");

    public void Revert(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Revert");
}
