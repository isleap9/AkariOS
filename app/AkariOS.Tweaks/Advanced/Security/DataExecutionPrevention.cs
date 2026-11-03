using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Security;

/// <summary>src/Tweaks/Advanced/Security/DataExecutionPrevention.ps1: nx in the current boot entry. AlwaysOff =
/// Optimized, OptIn or none = Default (Windows'); Revert deletes it.</summary>
[TweakCode("security-dep-off")]
public sealed partial class DataExecutionPrevention : ITweakCode
{
    [GeneratedRegex(@"^nx\s+(\S+)", RegexOptions.IgnoreCase)]
    private static partial Regex Nx();

    private static IBcdEdit Bcd(TweakContext c) => FileData.Need(c.Services.BcdEdit, "bcdedit");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var nx = Bcd(c).Read("{current}").Select(l => Nx().Match(l)).Where(m => m.Success).Select(m => m.Groups[1].Value).ToList();
        if (nx.Count == 0) return TweakState.Default;
        if (nx[0].Equals("AlwaysOff", StringComparison.OrdinalIgnoreCase)) return TweakState.Optimized;
        return nx[0].Equals("OptIn", StringComparison.OrdinalIgnoreCase) ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        if (Bcd(c).Run("/set {current} nx AlwaysOff") != 0) throw new InvalidOperationException("bcdedit could not set nx AlwaysOff");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        if (Bcd(c).Run("/deletevalue {current} nx") != 0) throw new InvalidOperationException("bcdedit could not reset nx");
    }
}
