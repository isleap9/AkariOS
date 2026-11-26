namespace AkariOS.App.Shell;

/// <summary>A Category's glyph (Cards.ps1's $AkariCategoryGlyphs) in Segoe Fluent Icons; settings for any other.</summary>
public static class CategoryGlyphs
{
    public const string Settings = "";

    public static IReadOnlyDictionary<string, string> All { get; } = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["Gaming"] = "", ["Performance"] = "", ["Power"] = "", ["Privacy"] = "", ["Network"] = "",
        ["Update"] = "", ["Security"] = "", ["Display"] = "", ["Tuning"] = "", ["Graphics"] = "",
        ["Input"] = "", ["Accessibility"] = "", ["Apps"] = "", ["Context menu"] = "", ["Explorer"] = "",
        ["Notifications"] = "", ["Sound"] = "", ["Start"] = "", ["System"] = "", ["Taskbar"] = "",
        ["Theme"] = "", ["Features"] = "", ["Scheduled tasks"] = "", ["Services"] = Settings, ["Check"] = "",
        ["Cleanup"] = "", ["Startup"] = "", ["Drivers"] = "", ["Fixes"] = "", ["Panels"] = "", ["Refresh"] = "", ["Setup"] = "",
    };

    public static string Of(string category) => All.GetValueOrDefault(category, Settings);

    /// <summary>A Review or run row's glyph: an app removal, an app install, else its Category's.</summary>
    public static string Of(Core.Tweaks.Tweak? t) => t is null ? Settings
        : t.Section == "Apps" ? (t.Category == "Install" ? "" : "")
        : Of(t.Category);
}
