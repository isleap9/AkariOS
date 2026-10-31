namespace AkariOS.App.Shell;

/// <summary>A page's header: its Lucide icon and the line under its title.</summary>
public sealed record PageInfo(string Glyph, string Sub);

/// <summary>The shell's rules (src/UI/Shell.ps1), pure: tabs, widths, which tab a page is on, the search hint.</summary>
public static class ShellLayout
{
    public const string CataloguePrefix = "Catalogue:";

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
        if (page.StartsWith(CataloguePrefix, StringComparison.Ordinal) || page == "Optimize") return "Search Optimize";
        if (page is "Downloads" or "Remove apps") return "Search apps";
        if (page == "Install AkariOS") return "Filter this step";
        return "Search Optimize";
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
