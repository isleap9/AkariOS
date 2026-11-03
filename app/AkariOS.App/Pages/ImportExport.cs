using System.IO;
using AkariOS.App.Shell;
using AkariOS.Core;

namespace AkariOS.App.Pages;

/// <summary>
/// Import / Export settings (src/UI/ImportExport.ps1): the Home tile's dialog and the options menu's two rows.
/// Export writes this PC's Tweak settings to a file as a preset (PresetStore.Export, the PowerShell app's format),
/// read in the background. Import reads such a file or any preset into Guided's Tweaks step (Review &amp; Apply as
/// usual), with a copy in the user's presets so Quick select lists it. Apps are not part of it.
/// </summary>
public static class ImportExport
{
    /// <summary>The Home tile: which way.</summary>
    public static void Show(AppServices s)
    {
        var q = "Export saves the settings this PC has (every AkariOS tweak that is applied, and each choice) to a file.\n\n" +
                "Import loads such a file, or any preset, and opens it in Guided, where you review the changes before applying them.\n\n" +
                "Removed and installed apps are not part of it.";
        switch (s.Dialogs?.Show(q, "Import / Export settings", ["Cancel", "Import...", "Export..."], "None"))
        {
            case "Import...": Import(s); break;
            case "Export...": Export(s); break;
        }
    }

    /// <summary>Start-AkariExport: a file picked, then this PC's settings written to it in the background.</summary>
    public static void Export(AppServices s)
    {
        if (s.Shell.Busy || s.Picker?.Save($"AkariOS settings {Environment.MachineName} {DateTime.Now:yyyy-MM-dd}.json") is not { } path) return;
        s.Shell.SetBusy(true, "Exporting settings");
        s.Log.Write($"Exporting settings to {path}");
        s.Background(() =>
        {
            try
            {
                var (file, count) = s.Engine.Presets.Export(s.Engine.Loaded.Tweaks, s.Engine.States, s.Engine.System, path, AkariInfo.Version, Environment.MachineName, DateTime.Now);
                return new Exported(file, count);
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { s.Log.WriteFile($"Error: export: {e}"); return null; }
        }, r =>
        {
            s.Shell.SetBusy(false);
            if (r is not Exported(var file, var count))
            {
                s.Dialogs?.Message("The settings could not be exported. The log has the details.", "Error", "Export settings");
                return;
            }
            s.Log.Write($"Exported {count} settings: {file}");
            s.Dialogs?.Message($"Exported {count} settings to:\n\n{file}", "Info", "Export settings");
        });
    }

    private sealed record Exported(string File, int Count);

    /// <summary>Start-AkariImport: a file picked and read; Install AkariOS › Guided opens on its Tweaks step with the
    /// file's changes picked (Quick select).</summary>
    public static void Import(AppServices s)
    {
        if (s.Shell.Busy || s.Picker?.Open() is not { } path) return;
        string? text = null;
        try { text = File.ReadAllText(path); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { s.Log.Write($"Warning: {path} could not be read ({e.Message})"); }
        var preset = text is null ? null : s.Engine.Presets.Read(text, path, false);
        if (preset is not { Entries.Count: > 0 })
        {
            s.Dialogs?.Message($"This file has no AkariOS settings in it:\n\n{path}", "Error", "Import settings");
            return;
        }
        // a copy in the user's presets (Quick select lists it); one already there by that name is replaced
        try
        {
            Directory.CreateDirectory(s.Engine.Presets.UserFolder);
            var dest = Path.Combine(s.Engine.Presets.UserFolder, Path.GetFileName(path));
            if (!string.Equals(Path.GetFullPath(path), Path.GetFullPath(dest), StringComparison.OrdinalIgnoreCase)) File.Copy(path, dest, overwrite: true);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { s.Log.Write($"Warning: the imported file was not copied to the presets ({e.Message})"); }
        s.Log.Write($"Import: {path}");
        s.Shell.Open("Install AkariOS");
        s.Install?.GuideTweaks(preset);
    }
}
