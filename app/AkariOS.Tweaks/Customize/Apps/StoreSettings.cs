using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>src/Tweaks/Customize/Apps/StoreSettings.ps1: the Store's settings hive from Files/store-settings.reg, {0} =
/// 00 (Apply) or 01 (Revert); Apply opens the Store's settings page first, both stop the Store.</summary>
[TweakCode("apps-store-settings")]
public sealed class StoreSettings : ITweakCode
{
    /// <summary>The .reg text with every setting's first byte.</summary>
    public static string RegText(Tweak t, TweakContext c, string first) =>
        c.Files.ReadText($"{TweakContext.FolderOf(t)}/Files/store-settings.reg").Replace("{0}", first);

    public TweakState Detect(Tweak tweak, TweakContext c) => AppHive.State(tweak, c);

    public void Apply(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Apply", RegText(tweak, c, "00"));

    public void Revert(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Revert", RegText(tweak, c, "01"));
}
