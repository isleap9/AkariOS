using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Presets;

/// <summary>One-click's own picks on the AkariOS preset (pure): the browser the user chose in place of the preset's
/// Helium, and no Ultimate Performance plan on a laptop (no sleep, CPU always at 100%: too much on battery).</summary>
public static class OneClickPicks
{
    /// <summary>The preset's browser: the one picked first.</summary>
    public const string DefaultBrowser = "install-helium";
    public const string Edge = "install-microsoft-edge";
    public const string RemoveEdge = "remove-edge";
    public const string PowerPlan = "power-ultimate-plan";
    public const string BrowserType = "Browsers";

    /// <summary>The browsers One-click can install: the preset's own first, then by name.</summary>
    public static IReadOnlyList<Tweak> Browsers(IEnumerable<Tweak> tweaks) =>
        tweaks.Where(t => t.AppType == BrowserType && t.Kind == TweakKind.Action)
            .OrderBy(t => t.Id != DefaultBrowser)
            .ThenBy(t => t.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToList();

    /// <summary>The preset with these picks: browser = an install Tweak's id, or null for none (the preset's browser
    /// left out). Edge picked keeps Edge (its removal left out). A laptop leaves the power plan out.</summary>
    public static Preset Apply(Preset preset, string? browser, Chassis chassis)
    {
        var entries = new List<PresetEntry>();
        var placed = false;
        foreach (var e in preset.Entries)
        {
            if (e.Id == DefaultBrowser)
            {
                if (browser is not null && !placed) entries.Add(e with { Id = browser });
                placed = true;
                continue;
            }
            if (e.Id == browser) { if (!placed) entries.Add(e); placed = true; continue; }
            if (e.Id == RemoveEdge && browser == Edge) continue;
            if (e.Id == PowerPlan && chassis == Chassis.Laptop) continue;
            entries.Add(e);
        }
        if (browser is not null && !placed) entries.Insert(0, new PresetEntry(browser, null, false, 0));
        return preset with { Entries = entries };
    }

    /// <summary>What the picks leave out, as lines for the log.</summary>
    public static IEnumerable<string> Notes(string? browser, Chassis chassis)
    {
        yield return browser is null ? "One-click: no browser installed." : $"One-click: browser {browser}.";
        if (browser == Edge) yield return "One-click: Microsoft Edge kept (remove-edge left out).";
        if (chassis == Chassis.Laptop) yield return "One-click: this PC is a laptop, the Ultimate Performance power plan is left out.";
    }
}
