using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>src/Tweaks/Customize/Apps/PhotosDeleteWarning.ps1: DeleteConfirmationDialogStatus in the Photos app's
/// settings hive; Revert deletes it.</summary>
[TweakCode("apps-photos-no-delete-warning")]
public sealed class PhotosDeleteWarning : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => AppHive.State(tweak, c);

    public void Apply(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Apply");

    public void Revert(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Revert");
}
