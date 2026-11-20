using AkariOS.Core.Tweaks;

namespace AkariOS.App.Shell;

/// <summary>A NavigationView entry: its key (the PowerShell app's page name), label, Segoe Fluent glyph, children.</summary>
public sealed record NavEntry(string Key, string Label, string Glyph, IReadOnlyList<NavEntry> Children)
{
    public NavEntry(string key, string label, string glyph) : this(key, label, glyph, []) { }
}

public enum NavPage { Home, Settings, Catalogue, Install, Downloads, RemoveApps, Placeholder }

/// <summary>A search box suggestion: the Tweak's name, its Section › Category under it.</summary>
public sealed record SearchSuggestion(Tweak Tweak)
{
    public string Name => Tweak.Name;
    public string Where => $"{Catalogue.HeaderOf(Tweak.Section)} › {Tweak.Category}";
    public override string ToString() => Tweak.Name;
}

/// <summary>A key's page: its kind, the page key it shows, the nav item to select (null: none), a search query.</summary>
public sealed record NavRoute(NavPage Page, string Key, string? NavKey, string Query);

/// <summary>
/// The left NavigationView, as Shell.ps1's $AkariNav: Home, Install AkariOS, Optimize (its Catalogue sections under
/// it), Downloads, Remove apps, Install USB, ISO Builder; Settings in the footer. Pure: the window builds from it.
/// </summary>
public static class NavTable
{
    public const string Settings = "Settings";
    public const string Install = "Install AkariOS";

    // Shell.ps1's icons in Segoe Fluent Icons (Segoe MDL2 Assets on Windows 10)
    private static readonly IReadOnlyDictionary<string, string> SectionGlyphs = new Dictionary<string, string>
    {
        ["Optimize"] = "", ["Customize"] = "", ["Hardware"] = "", ["Advanced"] = "", ["Tools"] = "",
    };

    public static IReadOnlyList<NavEntry> Menu { get; } =
    [
        new("Home", "Home", ""),
        new("Install AkariOS", "Install AkariOS", ""),
        new("Optimize", "Optimize", "",
            Catalogue.Sections.Select(s => new NavEntry(Catalogue.Prefix + s, Catalogue.HeaderOf(s), SectionGlyphs.GetValueOrDefault(s, ""))).ToList()),
        new("Downloads", "Downloads", ""),
        new("Remove apps", "Remove apps", ""),
        new("Install USB", "Install USB", ""),
        new("ISO Builder", "ISO Builder", ""),
    ];

    public static IReadOnlyList<NavEntry> Footer { get; } = [new(Settings, "Settings", "")];

    /// <summary>Every entry, children too.</summary>
    public static IEnumerable<NavEntry> All => Menu.Concat(Footer).SelectMany(e => e.Children.Prepend(e));

    public static NavEntry? Find(string key) => All.FirstOrDefault(e => string.Equals(e.Key, key, StringComparison.OrdinalIgnoreCase));

    /// <summary>A search's page key (the search box's query): the Catalogue's results.</summary>
    public const string SearchPrefix = "Search:";

    /// <summary>
    /// Where a key goes (Get-AkariNavKey): Optimize = its first Section; a Section or Category = the Catalogue page
    /// (a Category selects its Section's item); a search = the results (no item); else the page itself.
    /// </summary>
    public static NavRoute Route(string key)
    {
        if (key.StartsWith(SearchPrefix, StringComparison.Ordinal)) return new(NavPage.Catalogue, "", null, key[SearchPrefix.Length..]);
        if (key == "Optimize") key = Catalogue.Prefix + Catalogue.Sections[0];
        if (key.StartsWith(Catalogue.Prefix, StringComparison.Ordinal))
        {
            var section = Catalogue.Split(key)?.Section ?? key[Catalogue.Prefix.Length..];
            return new(NavPage.Catalogue, key, Catalogue.Prefix + section, "");
        }
        return key switch
        {
            "Home" => new(NavPage.Home, key, key, ""),
            Settings => new(NavPage.Settings, key, key, ""),
            Install => new(NavPage.Install, key, key, ""),
            "Downloads" => new(NavPage.Downloads, key, key, ""),
            "Remove apps" => new(NavPage.RemoveApps, key, key, ""),
            _ => new(NavPage.Placeholder, key, key, ""),
        };
    }

    /// <summary>The batch of the WinUI 3 plan (docs/plans/2026-11-19-native-winui-3.md) that brings a page still to come.</summary>
    public static string? ComingWith(string key) => key switch
    {
        "Home" or Settings or Install or "Downloads" or "Remove apps" => null,
        _ when key.StartsWith(Catalogue.Prefix, StringComparison.Ordinal) || key == "Optimize" => null,
        "Install USB" => "W7",
        "ISO Builder" => "W8",
        _ => null,
    };
}
