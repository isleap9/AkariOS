using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/AddPowerShellCmd.ps1: its Registry rows, which the file builds with code (a foreach over the four folder kinds), read out
/// of the file by RowScript.</summary>
[TweakCode("context-add-powershell-cmd")]
public sealed class AddPowerShellCmd : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => RowScript.Rows(tweak, c);
}
