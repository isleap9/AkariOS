namespace AkariOS.App.Views;

/// <summary>
/// Cross-page wizard state (pages are created on demand by the navigation service,
/// so acceptance/option state must outlive individual page instances).
/// </summary>
public static class WizardState
{
    public static bool LicenseAccepted { get; set; }

    /// <summary>Selected playbook option names, filled by the Configuration step.</summary>
    public static List<string> SelectedOptions { get; } = [];
}
