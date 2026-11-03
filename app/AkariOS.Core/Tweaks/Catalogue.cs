using AkariOS.Core.Data;
using AkariOS.Core.Machine;

namespace AkariOS.Core.Tweaks;

/// <summary>One Category page of the Catalogue: its key ("Catalogue:&lt;Section&gt;/&lt;Category&gt;") and Category.</summary>
public sealed record CataloguePage(string Key, string Category);

/// <summary>A Section of the Catalogue: its name, the header it shows, its Category pages by name.</summary>
public sealed record CatalogueSection(string Section, string Header, IReadOnlyList<CataloguePage> Pages);

/// <summary>What a Catalogue card is doing: its State is being read, its change waits in the queue or runs.</summary>
public enum CatalogueBusy { None, Reading, Waiting, Running }

/// <summary>
/// Optimize › Advanced, the Catalogue (ADR 0005), its pure part (src/UI/Catalogue.ps1): which Tweaks it lists, its
/// Section › Category pages, a page's list, the search, a card's State line and the restart bar's lines.
/// </summary>
public static class Catalogue
{
    public const string Prefix = "Catalogue:";

    /// <summary>Section order ($AkariCatalogueSections); other Sections come after them by name.</summary>
    public static IReadOnlyList<string> Sections { get; } = ["Optimize", "Customize", "Hardware", "Advanced", "Tools"];

    /// <summary>Sections shown under another name ($AkariCatalogueHeaders).</summary>
    public static IReadOnlyDictionary<string, string> Headers { get; } = new Dictionary<string, string> { ["Hardware"] = "Graphics & Hardware" };

    /// <summary>Category pages that also list what is on the PC under their Tweaks (N6 brings the lists), with the
    /// search box's placeholder there: the search filters that list ($AkariCatalogueLists).</summary>
    public static IReadOnlyDictionary<string, string> Lists { get; } = new Dictionary<string, string>
    {
        ["Catalogue:Advanced/Services"] = "Search services",
        ["Catalogue:Advanced/Scheduled tasks"] = "Search tasks",
    };

    // PowerShell's Sort-Object on text
    private static readonly StringComparer ByName = StringComparer.InvariantCultureIgnoreCase;

    /// <summary>The Tweaks it lists (Get-AkariCatalogueTweaks): one-file Toggles, Choices and Actions, no Group
    /// Entries, not the Apps or OneClick Sections, whose Requires this PC meets.</summary>
    public static IReadOnlyList<Tweak> Tweaks(IEnumerable<Tweak> loaded, ISystemInfo pc) =>
        loaded.Where(t => t.Group is null && t.EntryKind is null && t.Section is not ("Apps" or "OneClick")
            && t.Kind is TweakKind.Toggle or TweakKind.Choice or TweakKind.Action && Requirements.Check(t, pc) is null).ToList();

    public static string Key(string section, string category) => $"{Prefix}{section}/{category}";

    /// <summary>A page key's Section and Category; null when it isn't a Catalogue page.</summary>
    public static (string Section, string Category)? Split(string key)
    {
        if (!key.StartsWith(Prefix, StringComparison.Ordinal)) return null;
        var rest = key[Prefix.Length..];
        var i = rest.IndexOf('/');
        return i < 0 ? null : (rest[..i], rest[(i + 1)..]);
    }

    public static string HeaderOf(string section) => Headers.GetValueOrDefault(section) ?? section;

    /// <summary>The Sections with their Category pages (Get-AkariCataloguePages), from <see cref="Tweaks"/>'s list.</summary>
    public static IReadOnlyList<CatalogueSection> Pages(IReadOnlyList<Tweak> catalogue)
    {
        var sections = catalogue.Select(t => t.Section).Distinct().ToList();
        var ordered = Sections.Where(sections.Contains).Concat(sections.Where(s => !Sections.Contains(s)).OrderBy(s => s, ByName));
        return ordered.Select(s => new CatalogueSection(s, HeaderOf(s),
            catalogue.Where(t => t.Section == s).Select(t => t.Category).Distinct().OrderBy(c => c, ByName)
                .Select(c => new CataloguePage(Key(s, c), c)).ToList())).ToList();
    }

    /// <summary>A page's Tweaks, or with a query every Tweak whose name or description has it (PowerShell's
    /// -like), in page order (Get-AkariCatalogueList).</summary>
    public static IReadOnlyList<Tweak> List(IReadOnlyList<Tweak> catalogue, string key, string query)
    {
        if (query.Length > 0)
        {
            var order = Pages(catalogue).SelectMany(s => s.Pages).Select((p, i) => (p.Key, i)).ToDictionary(x => x.Key, x => x.i);
            return catalogue.Where(t => PsSemantics.Like($"{t.Name} {t.Description}", $"*{query}*"))
                .OrderBy(t => order[Key(t.Section, t.Category)]).ToList();
        }
        return catalogue.Where(t => Key(t.Section, t.Category) == key).ToList();
    }

    /// <summary>The restart bar's lines: Explorer changes and changes a PC restart finishes (Get-AkariRestartBarText).</summary>
    public static IReadOnlyList<string> RestartBarText(int explorer, int reboot)
    {
        static string S(int n) => n == 1 ? "" : "s";
        var lines = new List<string>();
        if (explorer > 0) lines.Add($"Explorer needs a restart to show {explorer} change{S(explorer)}.");
        if (reboot > 0) lines.Add($"A restart finishes {reboot} change{S(reboot)}.");
        return lines;
    }

    /// <summary>A card's State line (Get-AkariCatalogueStateText); an Action has none at rest.</summary>
    public static string StateText(Tweak tweak, TweakState state, CatalogueBusy busy, bool safePending) => busy switch
    {
        CatalogueBusy.Reading => "Reading…",
        CatalogueBusy.Waiting => "Waiting…",
        CatalogueBusy.Running => "Applying…",
        _ when safePending => "Waiting for Safe Mode",
        _ when tweak.Kind == TweakKind.Action => "",
        _ => state switch
        {
            TweakState.Optimized => "Optimized",
            TweakState.Default => "Windows default",
            TweakState.Custom => "Custom value",
            _ => "State unknown",
        },
    };
}
