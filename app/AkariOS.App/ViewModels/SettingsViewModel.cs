using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Support;
using AkariOS.Framework.Services;
using AkariOS.Framework.ViewModels;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.ViewModels;

/// <summary>A link (About.psd1's Links, Credits: Text = what it gave).</summary>
public sealed record LinkItem(string Name, string Text, string Url)
{
    public bool HasText => Text.Length > 0;
}

/// <summary>About's data, from the shared src/UI/About.psd1: links (an empty Url = hidden), credits, license.</summary>
public sealed record AboutData(IReadOnlyList<LinkItem> Links, IReadOnlyList<LinkItem> Credits, string FullCredits, string License, string LicenseUrl)
{
    public static AboutData Read(ISourceFiles files)
    {
        var h = (PsHashtable)PsData.Parse(files.ReadText("src/UI/About.psd1")).Value!;
        static string S(PsHashtable t, string k) => PsSemantics.Text(t.Get(k)) ?? "";
        var lic = (PsHashtable)h.Get("License")!;
        return new AboutData(
            PsSemantics.AsList(h.Get("Links")).OfType<PsHashtable>().Select(l => new LinkItem(S(l, "Name"), "", S(l, "Url"))).Where(l => l.Url.Length > 0).ToList(),
            PsSemantics.AsList(h.Get("Credits")).OfType<PsHashtable>().Select(c => new LinkItem(S(c, "Name"), S(c, "Text"), S(c, "Url"))).ToList(),
            S(h, "FullCredits"), S(lic, "Text"), S(lic, "Url"));
    }
}

/// <summary>
/// Settings (About.ps1's Show-AkariSettings): Appearance (App theme, Accent colour), Settings files (Import into
/// Guided, Export), Recovery (System Restore, Logs, the support file), About (the version, the update status, Check for updates, Update
/// now, What's new, links, credits, license). Windows' animation effects are WinUI's own (no setting here).
/// </summary>
public sealed partial class SettingsViewModel : ViewModelBase
{
    private readonly IThemeService _theme;
    private readonly ISettingsService _settings;
    private readonly IShellOpen _open;
    private readonly IFilePicker _picker;
    private readonly IDialogService _dialogs;
    private readonly IBackground _background;
    private readonly ShellState _shell;
    private readonly Engine _engine;
    private readonly Action<string> _applyAccent;
    private readonly InstallViewModel _install;
    private readonly DriftCheck? _drift;
    private readonly CatalogueViewModel? _catalogue;
    private readonly ActivityLog? _activity;
    private AppTheme _selectedTheme;
    private string _selectedAccent;

    public SettingsViewModel(IThemeService theme, ISettingsService settings, IShellOpen open, IFilePicker picker, IDialogService dialogs,
        IBackground background, ShellState shell, Engine engine, UpdateService updates, AccentChoice accent, InstallViewModel install,
        DriftCheck? drift = null, CatalogueViewModel? catalogue = null, ActivityLog? activity = null)
    {
        _install = install;
        _drift = drift;
        (_catalogue, _activity) = (catalogue, activity);
        (_theme, _settings, _open, _picker, _dialogs, _background, _shell, _engine) = (theme, settings, open, picker, dialogs, background, shell, engine);
        Updates = updates;
        _applyAccent = accent.Apply;
        _selectedTheme = theme.CurrentTheme;
        _selectedAccent = accent.Current;
        About = AboutData.Read(engine.Files);
        Title = "Settings";
    }

    public UpdateService Updates { get; }

    public AboutData About { get; }

    public IReadOnlyList<AppTheme> Themes { get; } = [AppTheme.Light, AppTheme.Dark, AppTheme.System];

    public AppTheme SelectedTheme
    {
        get => _selectedTheme;
        set
        {
            if (SetProperty(ref _selectedTheme, value)) _ = _theme.SetThemeAsync(value);
        }
    }

    public IReadOnlyList<ChoiceItem> Accents { get; } = Accent.Labels.Select(p => new ChoiceItem(p.Value, p.Key)).ToList();

    /// <summary>The accent dropdown: a <see cref="ChoiceItem"/> whose Value is Akari or Windows.</summary>
    public object? SelectedAccent
    {
        get => Accents.FirstOrDefault(a => a.Value as string == _selectedAccent);
        set
        {
            if (value is not ChoiceItem { Value: string v } || v == _selectedAccent) return;
            _selectedAccent = v;
            OnPropertyChanged();
            _ = _settings.SetAsync(Accent.Key, v);
            _applyAccent(v);
        }
    }

    public string VersionText => $"AkariOS {AkariInfo.Version}";

    public string LogFolder => AkariPaths.UserFolder;

    [RelayCommand]
    private void OpenLogFolder() => _open.Folder(AkariPaths.UserFolder);

    [RelayCommand]
    private void OpenSystemRestore() => _open.Program(Path.Combine(Environment.SystemDirectory, "rstrui.exe"));

    [RelayCommand]
    private void OpenLink(string? url)
    {
        if (!string.IsNullOrEmpty(url)) _open.Url(url);
    }

    [RelayCommand]
    private void CheckForUpdates() => Updates.Check(manual: true);

    [RelayCommand]
    private Task UpdateNow() => Updates.InstallAsync();

    /// <summary>Save-AkariSupportFile: a zip of the logs and this PC's details (names taken out), where the user picks;
    /// written in the background, then a toast that opens its folder. Nothing is sent anywhere.</summary>
    [RelayCommand]
    public async Task SaveSupportFileAsync()
    {
        if (await _picker.SaveZipAsync($"AkariOS-support-{DateTime.Now:yyyyMMdd-HHmm}.zip") is not { } path) return;
        var busy = _shell.Begin("Saving a support file");
        var done = new TaskCompletionSource<string?>();
        _background.Run(() =>
        {
            try
            {
                SupportFile.Make(path, SupportFile.Files(), SupportFile.Info(_engine, DateTime.Now), SupportFile.Users(_engine), Environment.MachineName, _engine.Log);
                return null;
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException or InvalidDataException)
            {
                _engine.Log.WriteFile($"Error: support file: {e}");
                return e.Message;
            }
        }, r => done.SetResult(r as string));
        var error = await done.Task;
        _shell.End(busy);
        if (error is not null)
        {
            _shell.Toast("Support file not saved", error, InfoBarSeverity.Error);
            return;
        }
        _engine.Log.Write($"Support file saved: {path}");
        _shell.Toast("Support file saved", path, InfoBarSeverity.Success, "Open folder", () => _open.Folder(Path.GetDirectoryName(path) ?? path));
    }

    /// <summary>Check my setup (X3): the drift check now; found = Guided with them picked, else a toast.</summary>
    [RelayCommand]
    public Task CheckSetupAsync() => _drift?.CheckAsync(manual: true) ?? Task.CompletedTask;

    public const string UndoTitle = "Undo the last run";

    /// <summary>Start-AkariUndo (X4): the newest Run record, what Undo can do with it asked first, then one change
    /// through the Catalogue's queue (the session's restore point first); an undone record is set aside, so the next
    /// Undo goes one Run further back.</summary>
    [RelayCommand]
    public async Task UndoAsync()
    {
        if (_engine.History is not { } history || _catalogue is null) return;
        if (history.Last() is not { } r)
        {
            await _dialogs.ShowInfoAsync(UndoTitle, "There is no Run to undo yet. Guided and One-click Runs are kept here, the last 10.");
            return;
        }
        var plan = Core.Runs.RunHistory.Plan(r, _engine.Find);
        if (plan.Exact.Count + plan.Default.Count == 0)
        {
            await _dialogs.ShowInfoAsync(UndoTitle, $"Nothing in \"{r.Name}\" can be undone here: it changed no settings, or only apps and one-time actions.");
            return;
        }
        if (!await _dialogs.ConfirmAsync(UndoTitle, Core.Runs.RunHistory.UndoText(r, plan, _engine.Find), "Undo", "Cancel")) return;
        var done = new TaskCompletionSource<object?>();
        _catalogue.Enqueue($"Undoing {r.Name}", restore: true, () => { },
            () => history.Undo(r, _engine.Find, _engine.Runner, _engine.Explorer, _engine.Expected), res => done.SetResult(res));
        var outs = await done.Task as IReadOnlyList<Core.Runs.Outcome> ?? [];
        var ok = outs.Count(o => o.Kind is Core.Runs.OutcomeKind.Reverted or Core.Runs.OutcomeKind.Already);
        var bad = outs.Where(o => o.Kind == Core.Runs.OutcomeKind.Failed).ToList();
        _activity?.Add($"Undid \"{r.Name}\"", "Settings", ok, "Undo");
        if (bad.Count > 0)
            _shell.Toast($"{ok} put back, {bad.Count} failed", string.Join('\n', bad.Select(o => $"{o.Id}: {o.Message}")) + "\nThe log has the details; Undo can be run again.",
                InfoBarSeverity.Warning);
        else _shell.Toast($"Undid {r.Name}", $"{ok} setting{(ok != 1 ? "s" : "")} put back. Restart Windows if a change asked for it.");
    }

    /// <summary>Start-AkariImport: a preset file into Install AkariOS › Guided's Tweaks step.</summary>
    [RelayCommand]
    public Task ImportAsync() => _install.ImportAsync();

    /// <summary>Start-AkariExport: a file picked, then this PC's settings written to it in the background (a preset
    /// named after the PC, the PowerShell app's format).</summary>
    [RelayCommand]
    public async Task ExportAsync()
    {
        if (_shell.IsBusy || await _picker.SaveJsonAsync($"AkariOS settings {Environment.MachineName} {DateTime.Now:yyyy-MM-dd}.json") is not { } path) return;
        var busy = _shell.Begin("Exporting settings");
        _engine.Log.Write($"Exporting settings to {path}");
        var done = new TaskCompletionSource<object?>();
        _background.Run(() =>
        {
            try { return _engine.Presets.Export(_engine.Loaded.Tweaks, _engine.States, _engine.System, path, AkariInfo.Version, Environment.MachineName, DateTime.Now); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { _engine.Log.WriteFile($"Error: export: {e}"); return null; }
        }, r => done.SetResult(r));
        var result = await done.Task;
        _shell.End(busy);
        if (result is not ValueTuple<string, int> (var file, var count))
        {
            _shell.Toast("Settings not exported", "The settings could not be exported. The log has the details.", InfoBarSeverity.Error);
            return;
        }
        _engine.Log.Write($"Exported {count} settings: {file}");
        _shell.Toast($"Exported {count} setting{(count == 1 ? "" : "s")}", file, InfoBarSeverity.Success, "Open folder",
            () => _open.Folder(Path.GetDirectoryName(file) ?? file));
    }
}

/// <summary>The accent setting and how to apply it (the window refreshes its theme so WinUI's brushes follow).</summary>
public sealed class AccentChoice(string current, Action<string> apply)
{
    public string Current { get; private set; } = current;

    public void Apply(string accent)
    {
        Current = accent;
        apply(accent);
    }
}
