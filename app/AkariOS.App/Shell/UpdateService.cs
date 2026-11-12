using System.IO;
using AkariOS.Core;
using AkariOS.Core.Update;

namespace AkariOS.App.Shell;

/// <summary>
/// The update check and install in the window (src/UI/About.ps1's part, on AkariOS.Core.Update): checked in the
/// background on every launch and from About's button; Home's bar and About show the status; on launch, still on
/// Home, an Available release asks Update now / Later. Installing downloads and swaps the exe (<see cref="Updater"/>),
/// then closes the app: the new exe is already starting.
/// </summary>
public sealed class UpdateService(IGitHub github, Updater updater, string exePath, bool developerBuild, Func<bool> runSaved, string current)
{
    public const string Title = "AkariOS update";

    /// <summary>The last check's status; null before the first one ends.</summary>
    public UpdateStatus? Status { get; private set; }

    public bool Checking { get; private set; }

    /// <summary>A check started or ended (Home's bar and About follow it).</summary>
    public event Action? Changed;

    /// <summary>Not a published single-file exe (dotnet build's output): it can't replace itself.</summary>
    // the empty Location of a single-file publish is what this reads (IL3000 warns about exactly that)
#pragma warning disable IL3000
    public static bool IsDeveloperBuild() => !string.IsNullOrEmpty(typeof(UpdateService).Assembly.Location);
#pragma warning restore IL3000

    /// <summary>The real one: GitHub, downloads and the new exe's start (guarded); the running exe, a saved Run in
    /// phases in %ProgramData%\AkariOS.Native.</summary>
    public static UpdateService Live(Core.Machine.IExe exe, IAkariLog log) =>
        new(new GitHubApi(), new Updater(new HttpDownloads(), exe, log), Environment.ProcessPath ?? "", IsDeveloperBuild(),
            () => File.Exists(Path.Combine(AkariPaths.MachineFolder, "run.json")), AkariInfo.Version);

    private UpdateBlocks Blocks(AppServices s) => new(developerBuild, runSaved(),
        s.Shell.Busy || s.Catalogue?.Running == true || s.Catalogue?.SafePending.Count > 0 || s.Install?.Running == true);

    /// <summary>Reads the latest release in the background; manual = About's button (the launch check asks on Home).</summary>
    public void Check(AppServices s, bool manual)
    {
        if (Checking) return;
        Checking = true;
        Changed?.Invoke();
        s.Background(() => Updates.Latest(github), r =>
        {
            Checking = false;
            Status = Updates.Status(current, r as Release ?? Release.Failed("Couldn't check for updates."), Blocks(s));
            s.Log.WriteFile($"Update check: {Status.Message}");
            Changed?.Invoke();
            if (!manual && Status.Kind == UpdateKind.Available && s.Shell.Page == "Home" && s.Shell.Search.Length == 0) Prompt(s);
        });
    }

    /// <summary>The launch prompt: the notes (shortened), Update now / Later.</summary>
    private void Prompt(AppServices s)
    {
        var notes = Updates.NotesText(Status!.Release.Notes);
        if (notes.Length > 600) notes = notes[..600].TrimEnd() + "…";
        var q = $"{Status.Message}\n\n" + (notes.Length > 0 ? $"What's new:\n{notes}\n\n" : "") +
                "Update now? AkariOS closes, installs it and opens again. Your presets and settings are kept.";
        if (s.Dialogs?.Confirm(q, "Update now", "Later", "Info", Title) == true) Install(s);
    }

    /// <summary>Checked again (something may have started since), then downloaded and swapped in the background; on
    /// Ok the app closes, else the reason is shown.</summary>
    public void Install(AppServices s)
    {
        if (Status is null || s.Shell.Busy) return;
        var now = Updates.Status(current, Status.Release, Blocks(s));
        if (now.Kind != UpdateKind.Available) { s.Dialogs?.Message(now.Message, "Info", Title); return; }
        s.Shell.SetBusy(true, $"Downloading AkariOS {now.Release.Version}…");
        s.Log.WriteFile($"Update: downloading AkariOS {now.Release.Version}");
        s.Background(() => updater.Install(now.Release, exePath), r =>
        {
            var result = r as UpdateResult ?? new UpdateResult(false, "The update could not be prepared.");
            if (result.Ok) { s.Close(); return; }
            s.Shell.SetBusy(false);
            s.Dialogs?.Message(result.Message, "Warning", Title);
        });
    }
}
