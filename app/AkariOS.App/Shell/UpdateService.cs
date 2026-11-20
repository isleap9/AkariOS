using AkariOS.App.ViewModels;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;

namespace AkariOS.App.Shell;

/// <summary>
/// The update check and install (src/UI/About.ps1's part, on AkariOS.Core.Update): checked in the background on every
/// launch and from Settings › About; Home's InfoBar and About show the status; on launch, still on Home, an Available
/// release asks Update now / Later. Installing downloads and swaps the exe (<see cref="Updater"/>), then closes the
/// app: the new exe is already starting.
/// </summary>
public sealed partial class UpdateService : ObservableObject
{
    public const string Title = "AkariOS update";

    private readonly IGitHub _github;
    private readonly Updater _updater;
    private readonly string _exePath;
    private readonly bool _developerBuild;
    private readonly Func<bool> _runSaved;
    private readonly string _current;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly ShellState _shell;
    private readonly CatalogueViewModel _catalogue;
    private readonly IAkariLog _log;
    private readonly Action _close;

    public UpdateService(IGitHub github, Updater updater, string exePath, bool developerBuild, Func<bool> runSaved, string current,
        IBackground background, IDialogService dialogs, ShellState shell, CatalogueViewModel catalogue, IAkariLog log, Action close)
    {
        (_github, _updater, _exePath, _developerBuild, _runSaved, _current) = (github, updater, exePath, developerBuild, runSaved, current);
        (_background, _dialogs, _shell, _catalogue, _log, _close) = (background, dialogs, shell, catalogue, log, close);
    }

    /// <summary>The last check's status; null before the first one ends.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(StatusText), nameof(Found), nameof(CanInstall), nameof(FoundTitle), nameof(Notes), nameof(HasNotes))]
    public partial UpdateStatus? Status { get; private set; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(StatusText))]
    public partial bool Checking { get; private set; }

    public string StatusText => Checking ? "Checking for updates…" : Status?.Message ?? "Not checked yet.";

    /// <summary>A newer release exists (Available, or Blocked by something running here).</summary>
    public bool Found => Status?.Kind is UpdateKind.Available or UpdateKind.Blocked;

    public string FoundTitle => Found ? $"AkariOS {Status!.Release.Version} is available" : "";

    public bool CanInstall => Status?.Kind == UpdateKind.Available;

    /// <summary>Home's update InfoBar was closed: not shown again this session.</summary>
    public bool Dismissed { get; set; }

    /// <summary>The release's notes as text (Settings › About's What's new).</summary>
    public string Notes => Status?.Release is { Ok: true } r ? Updates.NotesText(r.Notes) : "";

    public bool HasNotes => Notes.Length > 0;

    /// <summary>Not a published single-file exe (dotnet build's output): it can't replace itself.</summary>
    // the empty Location of a single-file publish is what this reads (IL3000 warns about exactly that)
#pragma warning disable IL3000
    public static bool IsDeveloperBuild() => !string.IsNullOrEmpty(typeof(UpdateService).Assembly.Location);
#pragma warning restore IL3000

    private UpdateBlocks Blocks() => new(_developerBuild, _runSaved(),
        _shell.IsBusy || _catalogue.Running || _catalogue.SafePending.Count > 0);

    /// <summary>Reads the latest release in the background; manual = About's button (the launch check asks on Home).</summary>
    public void Check(bool manual)
    {
        if (Checking) return;
        Checking = true;
        _background.Run(() => Updates.Latest(_github), r =>
        {
            Checking = false;
            Status = Updates.Status(_current, r as Release ?? Release.Failed("Couldn't check for updates."), Blocks());
            _log.WriteFile($"Update check: {Status.Message}");
            if (!manual && Status.Kind == UpdateKind.Available && _shell.Page == "Home") _ = PromptAsync();
        });
    }

    /// <summary>The launch prompt: the notes (shortened), Update now / Later.</summary>
    private async Task PromptAsync()
    {
        var notes = Updates.NotesText(Status!.Release.Notes);
        if (notes.Length > 600) notes = notes[..600].TrimEnd() + "…";
        var q = $"{Status.Message}\n\n" + (notes.Length > 0 ? $"What's new:\n{notes}\n\n" : "") +
                "Update now? AkariOS closes, installs it and opens again. Your presets and settings are kept.";
        if (await _dialogs.ConfirmAsync(Title, q, "Update now", "Later")) await InstallAsync();
    }

    /// <summary>Checked again (something may have started since), then downloaded and swapped in the background; on
    /// Ok the app closes, else the reason is shown.</summary>
    public async Task InstallAsync()
    {
        if (Status is null || _shell.IsBusy) return;
        var now = Updates.Status(_current, Status.Release, Blocks());
        if (now.Kind != UpdateKind.Available) { await _dialogs.ShowInfoAsync(Title, now.Message); return; }
        var busy = _shell.Begin($"Downloading AkariOS {now.Release.Version}…");
        _log.WriteFile($"Update: downloading AkariOS {now.Release.Version}");
        var done = new TaskCompletionSource<UpdateResult>();
        _background.Run(() => _updater.Install(now.Release, _exePath), r => done.SetResult(r as UpdateResult ?? new UpdateResult(false, "The update could not be prepared.")));
        var result = await done.Task;
        // ended first: closing asks while something still runs
        _shell.End(busy);
        if (result.Ok) { _close(); return; }
        await _dialogs.ShowErrorAsync(Title, result.Message);
    }

    /// <summary>The real one: GitHub, downloads and the new exe's start (guarded); the running exe, a saved Run in
    /// phases in %ProgramData%\AkariOS.Native.</summary>
    public static UpdateService Live(IBackground background, IDialogService dialogs, ShellState shell, CatalogueViewModel catalogue, IAkariLog log, Action close) =>
        new(new GitHubApi(), new Updater(new HttpDownloads(), new ExeRunner(), log), Environment.ProcessPath ?? "", IsDeveloperBuild(),
            () => File.Exists(Path.Combine(AkariPaths.MachineFolder, "run.json")), AkariInfo.Version, background, dialogs, shell, catalogue, log, close);
}
