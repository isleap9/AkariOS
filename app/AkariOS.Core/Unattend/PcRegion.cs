using System.Globalization;
using System.Text.RegularExpressions;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Unattend;

/// <summary>
/// Get-AkariUnattendDefaults: the display language Windows was installed with, the user's locale and time zone
/// (<paramref name="culture"/>), the first keyboard of the user's first language and their home location, read from
/// the real user's hive as Get-WinUserLanguageList and Get-WinHomeLocation read it (User Profile: the first of
/// Languages, its "lcid:klid" input methods in the order of their values; Geo\Nation).
/// </summary>
public sealed partial class RegistryPcRegion(RegistryEngine registry, Func<(string UILanguage, string Locale, string TimeZone)> culture) : IPcRegion
{
    private const string Profile = @"HKCU:\Control Panel\International\User Profile";

    /// <summary>This PC's (guarded: never under test).</summary>
    public static RegistryPcRegion Live(RegistryEngine registry)
    {
        SystemGuard.Check("the PC's language and time zone");
        return new(registry, () => (CultureInfo.InstalledUICulture.Name, CultureInfo.CurrentCulture.Name, TimeZoneInfo.Local.Id));
    }

    public PcRegion Read()
    {
        var (ui, locale, tz) = culture();
        return new PcRegion(ui, locale, Keyboard(), registry.GetValue(@"HKCU:\Control Panel\International\Geo", "Nation") as string ?? "244", tz);
    }

    /// <summary>The first input method's keyboard layout id, lower case; an IME or none = the US keyboard.</summary>
    private string Keyboard()
    {
        if (registry.GetValue(Profile, "Languages") is not string[] { Length: > 0 } languages) return "00000409";
        var key = Profile + @"\" + languages[0];
        var first = registry.ValueNames(key)
            .Select(n => (Name: n, Order: registry.GetValue(key, n)))
            .Where(v => v.Order is uint && v.Name.Contains(':'))
            .OrderBy(v => (uint)v.Order!)
            .Select(v => v.Name)
            .FirstOrDefault();
        var m = first == null ? null : Tip().Match(first);
        return m is { Success: true } ? m.Groups[1].Value.ToLowerInvariant() : "00000409";
    }

    [GeneratedRegex("^[0-9A-Fa-f]{4}:([0-9A-Fa-f]{8})$")]
    private static partial Regex Tip();
}
