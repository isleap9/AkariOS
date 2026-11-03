using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/AddTakeOwnership.ps1: its Registry rows, which the file builds with code (a helper for files and folders), read out
/// of the file by RowScript.</summary>
[TweakCode("context-add-take-ownership")]
public sealed class AddTakeOwnership : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => RowScript.Rows(tweak, c);
}
