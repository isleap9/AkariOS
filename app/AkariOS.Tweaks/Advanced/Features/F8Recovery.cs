using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Features;

/// <summary>src/Tweaks/Advanced/Features/F8Recovery.ps1 (winutil's Enable / DisableLegacyRecovery): bootmenupolicy in
/// the current boot entry. Legacy = Optimized, Standard or none = Default.</summary>
[TweakCode("features-f8-recovery")]
public sealed partial class F8Recovery : ITweakCode
{
    [GeneratedRegex(@"^bootmenupolicy\s+(\S+)", RegexOptions.IgnoreCase)]
    private static partial Regex Policy();

    private static IBcdEdit Bcd(TweakContext c) => FileData.Need(c.Services.BcdEdit, "bcdedit");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var p = Bcd(c).Read("{current}").Select(l => Policy().Match(l)).Where(m => m.Success).Select(m => m.Groups[1].Value).ToList();
        return p.Count > 0 && p[0].Equals("Legacy", StringComparison.OrdinalIgnoreCase) ? TweakState.Optimized : TweakState.Default;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(c, "legacy");

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(c, "standard");

    private static void Set(TweakContext c, string policy)
    {
        if (Bcd(c).Run($"/set {{current}} bootmenupolicy {policy}") != 0) throw new InvalidOperationException("bcdedit could not change the boot menu");
    }
}
