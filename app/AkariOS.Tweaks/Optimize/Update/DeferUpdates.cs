using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Update;

/// <summary>src/Tweaks/Optimize/Update/DeferUpdates.ps1: its Registry rows as the file lists them; the last one's value
/// is the file's $excluded, a list joined with ';', which PsData keeps as code: joined here.</summary>
[TweakCode("update-defer-policy")]
public sealed class DeferUpdates : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) =>
        PsSemantics.AsList(tweak.Fields.Get("Registry")).Cast<PsHashtable>().Select(h =>
            Loader.ToRow(h.Get("Value") is PsCode code ? h.With("Value", FileData.Joined(Resolve(tweak, c, code))) : h)!).ToList();

    // the row says "$excluded": the file's variable, itself the -join
    private static object? Resolve(Tweak tweak, TweakContext c, PsCode code) =>
        code.Text.Trim() is ['$', .. var name] ? FileData.Variable(tweak, c, name) : code;
}
