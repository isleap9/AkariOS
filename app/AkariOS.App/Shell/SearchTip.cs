using AkariOS.Framework.Services;

namespace AkariOS.App.Shell;

/// <summary>
/// The first run's tip next to the search box (Show-AkariSearchTip): "Search every Tweak", Ctrl+F. Shown on Home once,
/// until Got it or any dismissal; remembered in settings.json.
/// </summary>
public sealed class SearchTip(ISettingsService settings)
{
    public const string Key = "Shell.SearchTip";

    public static string Text(int tweaks) =>
        $"{tweaks} Tweaks across Optimize, Customize, Hardware, Advanced and Tools. Press Ctrl+F from anywhere.";

    public async Task<bool> ShouldShowAsync() => await settings.GetAsync(Key, "") != "Seen";

    public Task SeenAsync() => settings.SetAsync(Key, "Seen");
}
