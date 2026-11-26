using System.Globalization;
using AkariOS.Core.Machine;

namespace AkariOS.Core.Tweaks;

/// <summary>The Startup apps page's rules (the pure parts of src/UI/StartupPage.ps1, Oracle-tested).</summary>
public static class StartupLists
{
    /// <summary>$AkariStartupFilters.</summary>
    public static IReadOnlyList<string> Filters { get; } = ["All", "On", "Off", "User", "Machine"];

    /// <summary>Get-AkariStartupFilterLabel.</summary>
    public static string FilterLabel(string filter) => filter switch { "User" => "This user", "Machine" => "All users", _ => filter };

    private static readonly StringComparer ByName = StringComparer.Create(CultureInfo.CurrentCulture, ignoreCase: true);

    /// <summary>Get-AkariStartupView: the entries the filter and the search (name, command, publisher, location) leave,
    /// by name, then location.</summary>
    public static IReadOnlyList<StartupItem> View(IEnumerable<StartupItem> items, string filter, string query)
    {
        var q = query.Trim();
        return items.Where(i =>
        {
            var hit = filter switch
            {
                "On" => i.Enabled,
                "Off" => !i.Enabled,
                "User" => i.Scope == "User",
                "Machine" => i.Scope == "Machine",
                _ => true,
            };
            return hit && (q.Length == 0 || $"{i.Name} {i.Command} {i.Publisher} {i.Location}".Contains(q, StringComparison.OrdinalIgnoreCase));
        }).OrderBy(i => i.Name, ByName).ThenBy(i => i.Location, ByName).ToList();
    }

    /// <summary>Get-AkariStartupCountText: "n startup apps, m on", "x of n …" when filtered.</summary>
    public static string CountText(IReadOnlyCollection<StartupItem> all, IReadOnlyCollection<StartupItem> view)
    {
        var on = all.Count(i => i.Enabled);
        var apps = all.Count == 1 ? "startup app" : "startup apps";
        return view.Count == all.Count ? $"{all.Count} {apps}, {on} on" : $"{view.Count} of {all.Count} {apps}, {on} on";
    }
}
