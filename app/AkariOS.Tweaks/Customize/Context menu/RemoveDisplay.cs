using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/RemoveDisplay.ps1: Display settings hidden from the desktop menu by a
/// ProgrammaticAccessOnly value, written as TrustedInstaller (the key's owner).</summary>
[TweakCode("context-remove-display")]
public sealed class RemoveDisplay : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => TrustedRows.Detect(tweak, c);

    public void Apply(Tweak tweak, TweakContext c, object? value) => TrustedRows.Change(tweak, c, TweakMode.Apply);

    public void Revert(Tweak tweak, TweakContext c, object? value) => TrustedRows.Change(tweak, c, TweakMode.Revert);
}
