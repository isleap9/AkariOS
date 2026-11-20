using System.Globalization;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;

namespace AkariOS.Core.Tweaks;

/// <summary>A row of the Apps step: the Tweak or Entry, and whether it is on this PC.</summary>
public sealed record AppItem(Tweak Tweak, bool Installed);

/// <summary>An Install tab card: its title and rows.</summary>
public sealed record AppCard(string Title, IReadOnlyList<AppItem> Items);

/// <summary>
/// The Apps step's lists (the pure parts of src/UI/Apps.ps1, Oracle-tested): the Remove tab's Store apps and features,
/// the Install tab's cards, each row's source and icon file, the quick picks. No WPF, nothing read here.
/// </summary>
public static class AppLists
{
    /// <summary>$AkariAppTypes: the Install cards in order (another AppType goes under Other, before the restore card);
    /// System tools to Home server &amp; streaming and Languages &amp; SDKs came with winutil's apps (W5).</summary>
    public static IReadOnlyList<string> Types { get; } = ["Browsers", "Communication", "Game launchers", "Gaming & hardware", "Media", "Utilities",
        "System tools", "Documents", "Network & remote", "Home server & streaming", "Runtimes", "Dev tools", "Languages & SDKs"];

    /// <summary>Get-AkariInstallMark: a Caution install's mark (paid, or adds a driver or service; its description says
    /// which), or null for a Safe install and every removal (those have their Risk marks).</summary>
    public static (string Icon, string Brush, string Tip)? InstallMark(Tweak t) =>
        t.Category == "Install" && t.Risk == Risk.Caution
            ? ("triangle-alert", "Warn", "Check before installing: paid, or adds a driver or service")
            : null;

    /// <summary>$AkariRestoreType: Store apps and Windows tools the debloat removed, listed only while missing.</summary>
    public const string RestoreType = "Restore removed apps";

    // Sort-Object Name: the culture's order, case ignored; two rows with one name (an install and its Store restore)
    // by id (5.1's sort isn't stable: it puts them either way)
    private static readonly StringComparer ByName = StringComparer.Create(CultureInfo.CurrentCulture, ignoreCase: true);

    private static IReadOnlyList<AppItem> Sorted(IEnumerable<AppItem> items) =>
        items.OrderBy(i => i.Tweak.Name, ByName).ThenBy(i => i.Tweak.Id, StringComparer.Ordinal).ToList();

    /// <summary>Get-AkariAppList: every AppxRemove Entry of the data file, plus each installed package it doesn't list
    /// (an Entry built from its name); by name. installed = the removable package names on this PC.</summary>
    public static IReadOnlyList<AppItem> Store(IEnumerable<Tweak> tweaks, IEnumerable<TweakGroup> groups, IEnumerable<string> installed)
    {
        var g = groups.FirstOrDefault(x => x.EntryKind == EntryKind.AppxRemove);
        if (g is null) return [];
        var have = installed.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var list = tweaks.Where(t => t.Group == g.Id).ToList();
        var known = list.Select(t => t.Package).OfType<string>().ToHashSet(StringComparer.OrdinalIgnoreCase);
        list.AddRange(installed.Where(i => !known.Contains(i)).Select(i => Loader.NewEntry(g, PsHashtable.Of(("Name", i)))));
        return Sorted(list.Select(t => new AppItem(t, t.Package is { } p && have.Contains(p))));
    }

    /// <summary>Get-AkariFoundList: one Entry per name found on this PC (Optional or Windows features), by name.</summary>
    public static IReadOnlyList<AppItem> Found(IEnumerable<TweakGroup> groups, EntryKind kind, IEnumerable<string> names)
    {
        var g = groups.FirstOrDefault(x => x.EntryKind == kind);
        if (g is null) return [];
        return Sorted(names.Where(n => n.Length > 0).Select(n => new AppItem(Loader.NewEntry(g, PsHashtable.Of(("Name", n))), true)));
    }

    /// <summary>Get-AkariInstallList: the app installs this PC meets, by name.</summary>
    public static IReadOnlyList<AppItem> Install(IEnumerable<Tweak> tweaks, ISystemInfo pc) => Sorted(tweaks
        .Where(t => t.Section == "Apps" && t.Category == "Install" && (t.Requires.Count == 0 || Requirements.Check(t, pc) is null))
        .Select(t => new AppItem(t, true)));

    /// <summary>Get-AkariInstallCards: a card per AppType in <see cref="Types"/> order, Other, then the restore card
    /// with only the Store apps missing from this PC (appx: every package name on it).</summary>
    public static IReadOnlyList<AppCard> InstallCards(IEnumerable<Tweak> tweaks, ISystemInfo pc, IEnumerable<string> appx)
    {
        var have = appx.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var all = Install(tweaks, pc);
        var cards = new List<AppCard>();
        foreach (var type in Types)
        {
            var items = all.Where(i => string.Equals(i.Tweak.AppType, type, StringComparison.OrdinalIgnoreCase)).ToList();
            if (items.Count > 0) cards.Add(new AppCard(type, items));
        }
        var other = all.Where(i => !Types.Append(RestoreType).Contains(i.Tweak.AppType ?? "", StringComparer.OrdinalIgnoreCase)).ToList();
        if (other.Count > 0) cards.Add(new AppCard("Other", other));
        cards.Add(new AppCard(RestoreType, all.Where(i => string.Equals(i.Tweak.AppType, RestoreType, StringComparison.OrdinalIgnoreCase)
            && !(i.Tweak.Package is { } p && have.Contains(p))).ToList()));
        return cards;
    }

    /// <summary>$AkariDownloadCategories: Downloads' SelectorBar (after All) and the AppTypes under each.</summary>
    public static IReadOnlyList<KeyValuePair<string, string[]>> DownloadCategories { get; } =
    [
        new("Gaming", ["Game launchers", "Gaming & hardware"]),
        new("Browsers", ["Browsers"]),
        new("Communication", ["Communication"]),
        new("Media", ["Media"]),
        new("Tools", ["Utilities", "System tools", "Documents", "Network & remote", "Home server & streaming"]),
        new("Development", ["Runtimes", "Dev tools", "Languages & SDKs"]),
    ];

    /// <summary>$AkariDownloadRestore: the Store apps the debloat removed, under All only.</summary>
    public const string DownloadRestore = "Microsoft Store";

    /// <summary>Get-AkariDownloadCategory: an install's Downloads category (Tools for any other AppType).</summary>
    public static string DownloadCategory(Tweak t)
    {
        if (string.Equals(t.AppType, RestoreType, StringComparison.OrdinalIgnoreCase)) return DownloadRestore;
        foreach (var (k, types) in DownloadCategories)
            if (types.Contains(t.AppType ?? "", StringComparer.OrdinalIgnoreCase)) return k;
        return "Tools";
    }

    /// <summary>Get-AkariDownloadsView's cards: every install of the cards, by category in the SelectorBar's order
    /// (the Store's restores last), then by name.</summary>
    public static IReadOnlyList<AppItem> Downloads(IEnumerable<Tweak> tweaks, ISystemInfo pc, IEnumerable<string> appx)
    {
        var order = DownloadCategories.Select(c => c.Key).Append(DownloadRestore).ToList();
        return InstallCards(tweaks, pc, appx).SelectMany(c => c.Items)
            .OrderBy(i => order.IndexOf(DownloadCategory(i.Tweak))).ThenBy(i => i.Tweak.Name, ByName).ThenBy(i => i.Tweak.Id, StringComparer.Ordinal).ToList();
    }

    /// <summary>Get-AkariAppSource: the table's last column: the Store id, the package or feature name, the winget ids,
    /// the removal's id, or an AkariOS download.</summary>
    public static string Source(Tweak t)
    {
        if (!string.IsNullOrEmpty(t.StoreId)) return $"Microsoft Store: {t.StoreId}";
        if (!string.IsNullOrEmpty(t.Package)) return t.Package;
        if (t.Winget.Count > 0 && t.WingetSource == "msstore") return $"Microsoft Store: {string.Join(", ", t.Winget)}";
        if (t.Winget.Count > 0) return $"winget: {string.Join(", ", t.Winget)}";
        if (t.Category == "Remove") return t.Id;
        return "AkariOS download";
    }

    /// <summary>Get-AkariAppIconFile: an installed Store app's own logo (logos: package → file), else the bundled
    /// &lt;package or id&gt;.png or .mono.png in dir (exists: whether a file is there), else null.</summary>
    public static string? IconFile(Tweak t, IReadOnlyDictionary<string, string>? logos, string dir, Func<string, bool> exists)
    {
        if (!string.IsNullOrEmpty(t.Package) && logos is not null && logos.TryGetValue(t.Package, out var logo) && !string.IsNullOrEmpty(logo)) return logo;
        foreach (var k in new[] { t.Package, t.Id }.Where(k => !string.IsNullOrEmpty(k)))
            foreach (var f in new[] { Path.Combine(dir, $"{k}.png"), Path.Combine(dir, $"{k}.mono.png") })
                if (exists(f)) return f;
        return null;
    }

    /// <summary>A bundled icon is a black-or-white mask, drawn in the theme's text colour.</summary>
    public static bool IsMono(string file) => file.EndsWith(".mono.png", StringComparison.OrdinalIgnoreCase);

    /// <summary>A Remove-tab row (a removal; the rest are installs).</summary>
    public static bool IsRemoval(Tweak t) => t.Category == "Remove";

    /// <summary>Select recommended (Win11Debloat's pick): marked Recommended (Risk Safe).</summary>
    public static bool Recommended(Tweak t) => t.Risk == Risk.Safe;

    /// <summary>The AkariOS pick (FR33THY's): everything but the keep-list.</summary>
    public static bool AkariOSPick(Tweak t) => !t.Keep;

    /// <summary>A preset's app pick (Set-AkariQuickSelect): a non-Keep Entry of a Group the preset takes whole
    /// ("&lt;group&gt;/*"), or an id the preset resolved to.</summary>
    public static Func<Tweak, bool> PresetPick(IEnumerable<string> presetIds, IEnumerable<string> resolvedIds)
    {
        var wild = presetIds.Where(i => i.EndsWith("/*", StringComparison.Ordinal)).Select(i => i[..^2]).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var ids = resolvedIds.ToHashSet(StringComparer.Ordinal);
        return t => (t.Group is { } g && wild.Contains(g) && !t.Keep) || ids.Contains(t.Id);
    }
}
