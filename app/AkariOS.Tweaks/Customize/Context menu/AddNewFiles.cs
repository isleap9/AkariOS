using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/AddNewFiles.ps1: its Registry rows, which the file builds with code (a helper per file type), read out
/// of the file by RowScript.</summary>
[TweakCode("context-add-new-files")]
public sealed class AddNewFiles : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => RowScript.Rows(tweak, c);
}
