using AkariOS.App.Look;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Shell;

/// <summary>A page's header: its Lucide icon and the line under its title.</summary>
public sealed record PageInfo(string Glyph, string Sub);

/// <summary>The shell's rules (src/UI/Shell.ps1), pure: tabs, widths, which tab a page is on, the search hint.</summary>
public static class ShellLayout
{
    public const string CataloguePrefix = Catalogue.Prefix;

    /// <summary>The tabs and their icons ($AkariTabs). Optimize opens the Optimize page seen last.</summary>
    public static IReadOnlyList<(string Name, string Icon)> Tabs { get; } =
    [
        ("Home", "house"), ("Install AkariOS", "zap"), ("Optimize", "sliders-horizontal"), ("Downloads", "download"),
        ("Unattend Generator", "usb"), ("ISO Builder", "disc-3"),
    ];

    /// <summary>The labels six tabs fit with in a narrow window (the tab keeps its page name).</summary>
    public static IReadOnlyDictionary<string, string> TabShort { get; } = new Dictionary<string, string>
    {
        ["Install AkariOS"] = "Install", ["Unattend Generator"] = "Unattend", ["ISO Builder"] = "ISO",
    };

    /// <summary>Every page's header ($Pages; the native app has no Legacy pages, ADR 0007).</summary>
    public static IReadOnlyDictionary<string, PageInfo> Pages { get; } = new Dictionary<string, PageInfo>
    {
        ["Home"] = new("house", "Choose how you want to optimize Windows"),
        ["Install AkariOS"] = new("zap", "Optimize Windows in one click, or pick each change yourself"),
        ["Optimize"] = new("sliders-horizontal", "Every Tweak, by Section and Category, acting right away"),
        ["Downloads"] = new("download", "Install apps, runtimes and tools, from winget where possible"),
        ["Remove apps"] = new("trash-2", "Store apps, optional features, Windows features and legacy apps to remove"),
        ["Unattend Generator"] = new("usb", "An autounattend.xml for a Windows install USB, after Schneegans' generator"),
        ["ISO Builder"] = new("disc-3", "A custom Windows 11 ISO: apps removed and settings written in before it installs, after zISO Tweaker"),
        ["About"] = new("info", "Version, updates and credits"),
    };

    /// <summary>The tab a page belongs to ('' = none: About). Get-AkariTab.</summary>
    public static string TabOf(string page)
    {
        if (page is "Home" or "Install AkariOS" or "Downloads" or "Unattend Generator" or "ISO Builder") return page;
        if (page.StartsWith(CataloguePrefix, StringComparison.Ordinal) || page is "Optimize" or "Remove apps") return "Optimize";
        return "";
    }

    /// <summary>The search box's placeholder: what the search looks through there. Get-AkariSearchHint.</summary>
    public static string SearchHint(string page)
    {
        if (Catalogue.Lists.TryGetValue(page, out var hint)) return hint;
        if (page.StartsWith(CataloguePrefix, StringComparison.Ordinal) || page == "Optimize") return "Search Optimize";
        if (page is "Downloads" or "Remove apps") return "Search apps";
        if (page == "Install AkariOS") return "Filter this step";
        return "Search Optimize";
    }

    /// <summary>Pages whose search filters their own list (a step, the apps, the Services / Scheduled tasks lists);
    /// anywhere else the search looks through the Catalogue.</summary>
    public static bool OwnSearch(string page) => page is "Install AkariOS" or "Downloads" or "Remove apps" || Catalogue.Lists.ContainsKey(page);

    /// <summary>The page header (Show-Page, Show-AkariCataloguePage): a Catalogue page's Category, its Section and
    /// icon; the search's results; else the page's own. A page with a list of its own (Services, Scheduled tasks)
    /// keeps its header while the search filters that list (OwnSearch).</summary>
    public static (string Heading, string Sub, string Glyph) Header(string page, string query)
    {
        var cat = Catalogue.Split(page);
        if (query.Length > 0 && !OwnSearch(page)) return ("Search", $"Results for \"{query}\" in Optimize › Advanced", "search");
        if (cat is { } c) return (c.Category, $"{Catalogue.HeaderOf(c.Section)}. Each change applies right away.", Icons.Category(c.Category));
        var info = Pages.GetValueOrDefault(page) ?? new PageInfo("settings", "");
        return (page, info.Sub, info.Glyph);
    }

    /// <summary>The tabs at a width: icons from 1440 px, short labels under 1000. Get-AkariTabLayout.</summary>
    public static (bool Icons, bool Short) TabLayout(double width) => (width >= 1440, width < 1000);

    /// <summary>The label a tab shows at a width.</summary>
    public static string TabLabel(string tab, double width) =>
        TabLayout(width).Short && TabShort.TryGetValue(tab, out var s) ? s : tab;

    /// <summary>Under 1320 px the search is an icon button that opens the box.</summary>
    public static bool Narrow(double width) => width < 1320;

    /// <summary>Under 1000 px the wordmark goes (the tabs need the room).</summary>
    public static bool Wordmark(double width) => width >= 1000;

    /// <summary>Home's mode cards: all five in a row, three under 1320 px, two under 1000. Get-AkariHomeColumns.</summary>
    public static int HomeColumns(double width) => width < 1000 ? 2 : width < 1320 ? 3 : 5;

    /// <summary>The status bar's text for a job's progress: "label (n of total): step". Get-AkariProgressText.</summary>
    public static string ProgressText(string label, int done, int total, string? step)
    {
        if (total <= 0) return label;
        var t = $"{label} ({Math.Min(done + 1, total)} of {total})";
        return string.IsNullOrEmpty(step) ? t : $"{t}: {step}";
    }
}
