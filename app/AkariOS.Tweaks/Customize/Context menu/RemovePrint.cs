using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>src/Tweaks/Customize/Context menu/RemovePrint.ps1: ProgrammaticAccessOnly on each print verb this Windows
/// has, the rows Files/PrintVerbs.ps1's Get-AkariPrintVerbRows returns (read by RowScript, keys tested on the
/// registry). Unknown when Windows has none of them.</summary>
[TweakCode("context-remove-print")]
public sealed class RemovePrint : ITweakCode
{
    public static IReadOnlyList<RegistryRow> Verbs(Tweak t, TweakContext c) =>
        RowScript.Function(c, $"{TweakContext.FolderOf(t)}/Files/PrintVerbs.ps1", "Get-AkariPrintVerbRows");

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        Verbs(tweak, c) is { Count: > 0 } rows ? c.Registry.State(rows, c.System.Build) : TweakState.Unknown;

    public void Apply(Tweak tweak, TweakContext c, object? value) => c.Registry.Invoke(Verbs(tweak, c), TweakMode.Apply, c.System.Build);

    public void Revert(Tweak tweak, TweakContext c, object? value) => c.Registry.Invoke(Verbs(tweak, c), TweakMode.Revert, c.System.Build);
}
