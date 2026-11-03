using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/RemoveExtractAll.ps1: its Registry rows, which the file builds with code (a foreach over both views and both handlers), read out
/// of the file by RowScript.</summary>
[TweakCode("context-remove-extract-all")]
public sealed class RemoveExtractAll : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => RowScript.Rows(tweak, c);
}
