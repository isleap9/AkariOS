using System.Text.Json;
using AkariOS.Core;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Windows.UI;

namespace AkariOS.App.Shell;

/// <summary>The file dialogs, as paths (null = cancelled): the AkariOS settings files (*.json), answer files, folders.</summary>
public interface IFilePicker
{
    Task<string?> SaveJsonAsync(string suggestedName);
    Task<string?> OpenJsonAsync();

    /// <summary>An answer file to open (*.xml).</summary>
    Task<string?> OpenXmlAsync();

    /// <summary>A folder (Install USB's "Save to a folder…", the ISO Builder's work folder).</summary>
    Task<string?> FolderAsync();

    /// <summary>A Windows ISO (the ISO Builder's "Browse…").</summary>
    Task<string?> OpenIsoAsync();

    /// <summary>Where to save a zip (Settings › Recovery's support file).</summary>
    Task<string?> SaveZipAsync(string suggestedName);
}

/// <summary>
/// The real one, on the Windows App SDK's Microsoft.Windows.Storage.Pickers: they work in an elevated process, where
/// Windows.Storage.Pickers (the framework's IFilePickerService) fail. Guarded: tests use a fake.
/// </summary>
public sealed class WindowFilePicker : IFilePicker
{
    private readonly Func<WindowId> _window;

    public WindowFilePicker(Func<WindowId> window)
    {
        SystemGuard.Check("File dialogs");
        _window = window;
    }

    public async Task<string?> SaveJsonAsync(string suggestedName)
    {
        var picker = new Microsoft.Windows.Storage.Pickers.FileSavePicker(_window()) { SuggestedFileName = suggestedName, DefaultFileExtension = ".json" };
        picker.FileTypeChoices.Add("AkariOS settings", [".json"]);
        return (await picker.PickSaveFileAsync())?.Path;
    }

    public async Task<string?> SaveZipAsync(string suggestedName)
    {
        var picker = new Microsoft.Windows.Storage.Pickers.FileSavePicker(_window()) { SuggestedFileName = suggestedName, DefaultFileExtension = ".zip" };
        picker.FileTypeChoices.Add("Zip file", [".zip"]);
        return (await picker.PickSaveFileAsync())?.Path;
    }

    public async Task<string?> OpenJsonAsync()
    {
        var picker = new Microsoft.Windows.Storage.Pickers.FileOpenPicker(_window());
        picker.FileTypeFilter.Add(".json");
        return (await picker.PickSingleFileAsync())?.Path;
    }

    public async Task<string?> OpenXmlAsync()
    {
        var picker = new Microsoft.Windows.Storage.Pickers.FileOpenPicker(_window());
        picker.FileTypeFilter.Add(".xml");
        return (await picker.PickSingleFileAsync())?.Path;
    }

    public async Task<string?> OpenIsoAsync()
    {
        var picker = new Microsoft.Windows.Storage.Pickers.FileOpenPicker(_window());
        picker.FileTypeFilter.Add(".iso");
        return (await picker.PickSingleFileAsync())?.Path;
    }

    public async Task<string?> FolderAsync()
    {
        var picker = new Microsoft.Windows.Storage.Pickers.FolderPicker(_window());
        return (await picker.PickSingleFolderAsync())?.Path;
    }
}

/// <summary>
/// Settings › Accent colour (Set-AkariAccent): Akari crimson (ADR 0008's values on WinUI's accent ramp) or the Windows
/// accent (WinUI's own: the crimson keys removed). Saved as <c>Appearance.Accent</c>.
/// </summary>
public static class Accent
{
    public const string Key = "Appearance.Accent";
    public const string Akari = "Akari";
    public const string Windows = "Windows";

    public static IReadOnlyList<KeyValuePair<string, string>> Labels { get; } =
        [new(Akari, "Akari crimson"), new(Windows, "Windows accent")];

    /// <summary>Akari crimson: Acc #FF6B7D dark = Light2, #C8102E light = Dark1; AccText #FFA3AE dark = Light3,
    /// #9E0C24 light = Dark2.</summary>
    public static IReadOnlyDictionary<string, Color> Crimson { get; } = new Dictionary<string, Color>
    {
        ["SystemAccentColor"] = Rgb(0xE0, 0x26, 0x3F),
        ["SystemAccentColorLight1"] = Rgb(0xF0, 0x4A, 0x5E),
        ["SystemAccentColorLight2"] = Rgb(0xFF, 0x6B, 0x7D),
        ["SystemAccentColorLight3"] = Rgb(0xFF, 0xA3, 0xAE),
        ["SystemAccentColorDark1"] = Rgb(0xC8, 0x10, 0x2E),
        ["SystemAccentColorDark2"] = Rgb(0x9E, 0x0C, 0x24),
        ["SystemAccentColorDark3"] = Rgb(0x75, 0x09, 0x1B),
    };

    private static Color Rgb(byte r, byte g, byte b) => Color.FromArgb(0xFF, r, g, b);

    /// <summary>Puts the accent into the app's resources (before the window is made, or followed by a theme refresh).</summary>
    public static void Apply(ResourceDictionary resources, string accent)
    {
        foreach (var (k, c) in Crimson)
        {
            if (accent == Windows) resources.Remove(k);
            else resources[k] = c;
        }
    }
}

/// <summary>One line of Recent activity (Add-AkariActivity): what ran, where, how many changes, when.</summary>
public sealed record Activity(string Title, string Where, int Count, string Icon, DateTime When);

/// <summary>
/// Recent activity (Pages.ps1): the last runs, each with its count of changes, in activity.json next to akari.log
/// (at most 20, newest first; the PowerShell app's format).
/// </summary>
public sealed class ActivityLog(string path, IAkariLog log)
{
    public const int Max = 20;

    public static string Default => Path.Combine(AkariPaths.UserFolder, "activity.json");

    public IReadOnlyList<Activity> All()
    {
        try
        {
            if (!File.Exists(path)) return [];
            return JsonSerializer.Deserialize<List<Activity>>(File.ReadAllText(path)) ?? [];
        }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { return []; }
    }

    public void Add(string title, string where, int count, string icon, DateTime? when = null)
    {
        var list = All().Take(Max - 1).Prepend(new Activity(title, where, count, icon, when ?? DateTime.Now)).ToList();
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, JsonSerializer.Serialize(list, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { log.WriteFile($"Could not save the activity: {e.Message}"); }
        Added?.Invoke();
    }

    /// <summary>An activity was added (Home shows it).</summary>
    public event Action? Added;

    /// <summary>Get-AkariWhenText: "Just now", "12 minutes ago", "Today 14:05", "Yesterday", or the date.</summary>
    public static string WhenText(DateTime when, DateTime now)
    {
        var d = now - when;
        if (d.TotalMinutes < 1) return "Just now";
        if (d.TotalMinutes < 60)
        {
            var m = (int)Math.Floor(d.TotalMinutes);
            return $"{m} minute{(m != 1 ? "s" : "")} ago";
        }
        if (when.Date == now.Date) return "Today " + when.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture);
        if (when.Date == now.Date.AddDays(-1)) return "Yesterday";
        return when.ToString("d MMM yyyy", System.Globalization.CultureInfo.InvariantCulture);
    }
}
