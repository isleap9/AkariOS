namespace AkariOS.App.Views;

/// <summary>
/// Tracks the playbook flow across the shell's step pages (which are separate Page classes
/// created on demand by the navigation service).
/// </summary>
public static class WizardFlow
{
    public sealed record Step(string Label, string Glyph, Type PageType);

    /// <summary>Ordered step pages, matching the nav pane.</summary>
    public static readonly IReadOnlyList<Step> Steps =
    [
        new("License Agreement", "\uE8FA", typeof(LicensePage)),
        new("System Check", "\uE9D9", typeof(SystemCheckPage)),
        new("Configuration", "\uE713", typeof(ConfigurationPage)),
        new("Optimization", "\uE9F5", typeof(OptimizationPage)),
        new("Finished", "\uE73E", typeof(FinishedPage)),
    ];

    public static int IndexOf(Type pageType)
    {
        for (var i = 0; i < Steps.Count; i++)
            if (Steps[i].PageType == pageType) return i;
        return -1;
    }

    public static bool LicenseAccepted { get; set; }

    /// <summary>Raised whenever flow state changes so the shell can re-evaluate button gating.</summary>
    public static event EventHandler? StateChanged;

    public static void NotifyStateChanged() => StateChanged?.Invoke(null, EventArgs.Empty);

    /// <summary>Option names ticked on the Configuration page, passed to the engine.</summary>
    public static List<string> SelectedOptions { get; } = [];

    /// <summary>All playbook requirements satisfied (System Check passed).</summary>
    public static bool RequirementsMet { get; set; }

    /// <summary>The engine run finished successfully at least once.</summary>
    public static bool RunCompleted { get; set; }
}
