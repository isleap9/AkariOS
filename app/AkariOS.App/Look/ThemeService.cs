using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Windows;

namespace AkariOS.App.Look;

/// <summary>The native app's settings.json next to its akari.log: { "Theme": "System" | "Dark" | "Light", ... }.</summary>
public sealed class SettingsFile(string path)
{
    public string Path { get; } = path;

    public JsonObject Read()
    {
        try { return JsonNode.Parse(File.ReadAllText(Path)) as JsonObject ?? []; }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { return []; }
    }

    public string? Get(string key) => Read()[key] is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;

    /// <summary>Sets one key and keeps the others. Never throws (a failed save keeps the old file).</summary>
    public bool Set(string key, string value)
    {
        try
        {
            var s = Read();
            s[key] = value;
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path)!);
            File.WriteAllText(Path, s.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            return true;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return false; }
    }
}

/// <summary>
/// The theme (Set-AkariTheme): System, Dark or Light, saved as settings.json's Theme; System follows Windows' app
/// mode (AppsUseLightTheme, the real user's) and changes with it. Applying swaps Theme.Dark.xaml / Theme.Light.xaml in
/// the resources: every brush is a DynamicResource, so the window repaints.
/// </summary>
public sealed class ThemeService(ResourceDictionary resources, SettingsFile settings, Func<int?> appsUseLightTheme, bool motionOn)
{
    public static readonly IReadOnlyList<string> Settings = ["System", "Dark", "Light"];

    /// <summary>System, Dark or Light: what the user picked.</summary>
    public string Setting { get; private set; } = "System";

    /// <summary>Dark or Light: what shows.</summary>
    public string Current { get; private set; } = "Dark";

    /// <summary>After every Apply (the frame, the logo follow it).</summary>
    public event Action? Changed;

    /// <summary>System -> Dark or Light from AppsUseLightTheme (1 = light); Dark when it can't be read. Pure.</summary>
    public static string Resolve(string setting, int? appsUseLightTheme) =>
        setting is "Dark" or "Light" ? setting : appsUseLightTheme == 1 ? "Light" : "Dark";

    /// <summary>The saved setting (System when none or not one of the three).</summary>
    public string Saved() => settings.Get("Theme") is { } t && Settings.Contains(t) ? t : "System";

    public void Apply(string setting, bool save = false)
    {
        if (!Settings.Contains(setting)) setting = "System";
        int? light;
        try { light = appsUseLightTheme(); } catch (Exception) { light = null; }
        var name = Resolve(setting, light);
        var dict = (ResourceDictionary)AkariXaml.Load($"Theme.{name}.xaml", motionOn);
        var merged = resources.MergedDictionaries;
        if (merged.Count > AkariXaml.ThemeIndex) merged[AkariXaml.ThemeIndex] = dict;
        else merged.Add(dict);
        (Setting, Current) = (setting, name);
        if (save) settings.Set("Theme", setting);
        Changed?.Invoke();
    }

    /// <summary>The next one in the options menu's cycle: System, Dark, Light.</summary>
    public static string Next(string setting) => Settings[(Settings.ToList().IndexOf(setting) + 1) % Settings.Count];
}
