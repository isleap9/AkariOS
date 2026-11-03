using System.Globalization;
using System.Text.RegularExpressions;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Power;

/// <summary>src/Tweaks/Optimize/Power/SignInAfterSleep.ps1: the active plan's "require sign-in on wake" (consolelock),
/// AC and DC. Detect reads the last two indexes powercfg /qh prints for it (": 0x00000000"), whatever the language.</summary>
[TweakCode("power-no-sign-in-after-sleep")]
public sealed partial class SignInAfterSleep : ITweakCode
{
    [GeneratedRegex(@":\s*0x([0-9a-f]{8})\s*$", RegexOptions.IgnoreCase)]
    private static partial Regex Index();

    /// <summary>The AC and DC indexes in powercfg's output (the last two), or fewer when it doesn't say.</summary>
    public static IReadOnlyList<int> Indexes(IEnumerable<string> lines) =>
        lines.Select(l => Index().Match(l)).Where(m => m.Success).Select(m => int.Parse(m.Groups[1].Value, NumberStyles.HexNumber, CultureInfo.InvariantCulture)).TakeLast(2).ToList();

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var v = Indexes(Power.Cfg(c).Run("/qh", "scheme_current", "sub_none", "consolelock"));
        if (v.Count < 2) return TweakState.Unknown;
        return v.All(x => x == 0) ? TweakState.Optimized : v.All(x => x == 1) ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(c, "0");

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(c, "1");

    private static void Set(TweakContext c, string index)
    {
        Power.Cfg(c).Run("/setacvalueindex", "scheme_current", "sub_none", "consolelock", index);
        Power.Cfg(c).Run("/setdcvalueindex", "scheme_current", "sub_none", "consolelock", index);
    }
}
