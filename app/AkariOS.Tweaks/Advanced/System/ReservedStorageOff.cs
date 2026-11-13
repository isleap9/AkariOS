using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.SystemTweaks;

/// <summary>src/Tweaks/Advanced/System/ReservedStorageOff.ps1 (winutil W3): reserved storage through dism.exe
/// (Disabled = Optimized, Enabled = Default, none = Unknown); a refusal (an update in progress) fails saying why.</summary>
[TweakCode("system-reserved-storage-off")]
public sealed class ReservedStorageOff : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => FileData.Need(c.Services.Dism, "DISM").ReservedStorage() switch
    {
        "Disabled" => TweakState.Optimized,
        "Enabled" => TweakState.Default,
        _ => TweakState.Unknown,
    };

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(c, "Disabled");

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(c, "Enabled");

    private static void Set(TweakContext c, string state)
    {
        var code = FileData.Need(c.Services.Dism, "DISM").Exe("/Online", "/Set-ReservedStorageState", $"/State:{state}");
        if (code != 0) throw new InvalidOperationException($"DISM could not change reserved storage (0x{code:X8}): let Windows Update finish, restart, then try again.");
    }
}
