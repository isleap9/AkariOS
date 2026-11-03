using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/AddLegacySettings.ps1: its Registry rows, which the file builds with code (a helper per submenu item), read out
/// of the file by RowScript.</summary>
[TweakCode("context-add-legacy-settings")]
public sealed class AddLegacySettings : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => RowScript.Rows(tweak, c);
}
