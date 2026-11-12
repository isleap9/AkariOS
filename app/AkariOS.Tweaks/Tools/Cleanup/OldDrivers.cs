using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/OldDrivers.ps1 (ZOICWARE): driver packages with the same original .inf, provider and
/// class as a newer one, deleted through pnputil without /force (one a device uses stays). An Action: a deleted driver
/// package can't come back.</summary>
[TweakCode("cleanup-old-drivers")]
public sealed class OldDrivers : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var old = Old(TweakServices.Need(c.Services.Dism, "DISM").Drivers());
        var pnputil = TweakServices.Need(c.Services.PnpUtil, "pnputil");
        var n = old.Count(d => pnputil.DeleteDriver(d.Driver) == 0);
        c.Log.Write($"Deleted {n} of {old.Count} old driver packages");
    }

    /// <summary>Each group (Group-Object: first seen first, keys ignoring case) newest first by version (unreadable =
    /// 0.0), then date; all but the first.</summary>
    public static List<DriverPackage> Old(IEnumerable<DriverPackage> packages) => packages
        .GroupBy(d => $"{Path.GetFileName(d.OriginalFileName)}|{d.ProviderName}|{d.ClassName}", StringComparer.OrdinalIgnoreCase)
        .Where(g => g.Count() > 1)
        .SelectMany(g => g.OrderByDescending(d => Version.TryParse(d.Version, out var v) ? v : new Version(0, 0)).ThenByDescending(d => d.Date).Skip(1))
        .ToList();
}
