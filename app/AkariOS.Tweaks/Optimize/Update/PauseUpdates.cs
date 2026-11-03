using System.Globalization;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Update;

/// <summary>src/Tweaks/Optimize/Update/PauseUpdates.ps1: Windows Update paused for 365 days from now (dates, so code,
/// not rows). Optimized while the pause hasn't ended; Revert = no pause (Windows Update's Resume).</summary>
[TweakCode("update-pause-one-year")]
public sealed class PauseUpdates : ITweakCode
{
    private const string Key = @"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings";
    private static readonly string[] Ends = ["PauseUpdatesExpiryTime", "PauseFeatureUpdatesEndTime", "PauseQualityUpdatesEndTime"];
    private static readonly string[] Starts = ["PauseUpdatesStartTime", "PauseFeatureUpdatesStartTime", "PauseQualityUpdatesStartTime"];

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        if (PsSemantics.Text(c.Registry.GetValue(Key, "PauseUpdatesExpiryTime")) is not { Length: > 0 } end) return TweakState.Default;
        if (!DateTime.TryParse(end, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeLocal, out var at)) return TweakState.Custom;
        return at > c.Services.UtcNow() ? TweakState.Optimized : TweakState.Default;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var now = c.Services.UtcNow();
        var start = now.ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture);
        var end = now.AddDays(365).ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture);
        foreach (var n in Ends) c.Registry.SetValue(Key, n, end, "String");
        foreach (var n in Starts) c.Registry.SetValue(Key, n, start, "String");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var n in Ends.Concat(Starts)) c.Registry.RemoveValue(Key, n);
    }
}
