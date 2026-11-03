using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.SystemTweaks; // not .System: it would hide .NET's System namespace

/// <summary>src/Tweaks/Customize/System/NoBootUi.ps1: bootuxdisabled in the boot store's {globalsettings}. Detect: the
/// setting there at all = Optimized (bcdedit prints its Yes / No in the system language); Revert deletes it.</summary>
[TweakCode("system-no-boot-ui")]
public sealed partial class NoBootUi : ITweakCode
{
    [GeneratedRegex(@"^bootuxdisabled\s", RegexOptions.IgnoreCase)]
    private static partial Regex Setting();

    private static IBcdEdit Bcd(TweakContext c) => FileData.Need(c.Services.BcdEdit, "bcdedit");

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        Bcd(c).Read("{globalsettings}").Any(l => Setting().IsMatch(l)) ? TweakState.Optimized : TweakState.Default;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        if (Bcd(c).Run("/set {globalsettings} bootuxdisabled on") != 0) throw new InvalidOperationException("bcdedit could not change the boot settings");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value) => Bcd(c).Run("/deletevalue {globalsettings} bootuxdisabled");
}
