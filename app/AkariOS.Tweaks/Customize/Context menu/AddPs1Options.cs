using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/AddPs1Options.ps1: its Registry rows, which the file builds with code (a helper per submenu item, with switches), read out
/// of the file by RowScript.</summary>
[TweakCode("context-add-ps1-options")]
public sealed class AddPs1Options : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => RowScript.Rows(tweak, c);
}
