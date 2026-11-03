using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>src/Tweaks/Customize/Apps/AppActions.ps1: the Windows shell's DisabledApps values (its own settings hive),
/// written with the shell's helpers stopped; nothing to change while the shell has no settings file.</summary>
[TweakCode("apps-app-actions-off")]
public sealed class AppActions : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => AppHive.State(tweak, c);

    public void Apply(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Apply");

    public void Revert(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Revert");
}
