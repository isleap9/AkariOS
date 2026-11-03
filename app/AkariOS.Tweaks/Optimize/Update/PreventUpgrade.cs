using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Update;

/// <summary>src/Tweaks/Optimize/Update/PreventUpgrade.ps1: the target release policy held at the Windows and version
/// this PC runs (ISystemInfo: its build and DisplayVersion, read when applied); Revert deletes the policies.</summary>
[TweakCode("update-prevent-os-upgrade")]
public sealed class PreventUpgrade : ITweakCode
{
    private const string Key = @"HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate";
    private static readonly string[] Names = ["ProductVersion", "TargetReleaseVersion", "TargetReleaseVersionInfo"];

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var on = c.Registry.GetValue(Key, "TargetReleaseVersion");
        var info = c.Registry.GetValue(Key, "TargetReleaseVersionInfo");
        var pv = c.Registry.GetValue(Key, "ProductVersion");
        if (on is not null && PsSemantics.LooseEquals(on, 1) && PsSemantics.Truthy(info) && PsSemantics.Truthy(pv)) return TweakState.Optimized;
        return on is null && info is null && pv is null ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var version = c.System.DisplayVersion ?? throw new InvalidOperationException("this Windows does not say its version");
        c.Registry.SetValue(Key, "ProductVersion", c.System.Build >= 22000 ? "Windows 11" : "Windows 10", "String");
        c.Registry.SetValue(Key, "TargetReleaseVersion", 1, "DWord");
        c.Registry.SetValue(Key, "TargetReleaseVersionInfo", version, "String");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var n in Names) c.Registry.RemoveValue(Key, n);
    }
}
