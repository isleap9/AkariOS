using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.ContextMenu;

/// <summary>A Tweak whose blocks hand their rows to Get-AkariRegistryState (Detect) and Invoke-AkariRegistryTrusted
/// (Apply / Revert): each block's own <c>@(@{ … })</c> rows, read out of it, written as TrustedInstaller.</summary>
public static partial class TrustedRows
{
    [GeneratedRegex(@"@\((?<rows>@\{.*\})\)", RegexOptions.Singleline)]
    private static partial Regex RowList();

    public static IReadOnlyList<RegistryRow> Of(Tweak t, string block)
    {
        var text = (t.Fields.Get(block) as PsScriptBlock)?.Text ?? throw new InvalidOperationException($"{t.Source} has no {block} block");
        var m = RowList().Match(text);
        if (!m.Success) throw new InvalidOperationException($"{t.Source}: no rows in {block}");
        return PsSemantics.AsList(PsData.ParseValue(m.Groups["rows"].Value)).Cast<PsHashtable>()
            .Select(h => Loader.ToRow(h) ?? throw new InvalidOperationException($"{t.Source}: a row with no Path")).ToList();
    }

    public static TweakState Detect(Tweak t, TweakContext c) => c.Registry.State(Of(t, "Detect"), c.System.Build);

    public static void Change(Tweak t, TweakContext c, TweakMode mode) =>
        c.Registry.Invoke(Of(t, mode.ToString()), mode, c.System.Build, asTrusted: true);
}
