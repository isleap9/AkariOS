using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.App.Look;

namespace AkariOS.App.Shell;

/// <summary>What pages work with: the engine, the shell's state, the theme, dialogs, the opener, the log.</summary>
public sealed class AppServices
{
    public required Engine Engine { get; init; }
    public required ShellViewModel Shell { get; init; }
    public required ThemeService Theme { get; init; }
    public required IShellOpen Open { get; init; }
    public required IAkariLog Log { get; init; }

    /// <summary>Set once the window is up (dialogs are shown over it).</summary>
    public Dialogs? Dialogs { get; set; }

    /// <summary>Home's "changes applied", read once per run; and whether Home was shown (its cards stagger once).</summary>
    public int? AppliedCount { get; set; }

    /// <summary>Home's "Removable apps": the Store apps on this PC the AkariOS pick removes (read once, again after a Run).</summary>
    public int? RemovableCount { get; set; }
    public bool HomeShown { get; set; }

    /// <summary>The log folder (Open log folder, Logs).</summary>
    public string LogFolder { get; init; } = AkariPaths.UserFolder;

    /// <summary>Runs work off the UI thread and hands its result back on it (tests run it at once).</summary>
    public Action<Func<object?>, Action<object?>> Background { get; init; } = (work, done) =>
    {
        var ui = System.Windows.Threading.Dispatcher.CurrentDispatcher;
        Task.Run(() =>
        {
            object? r;
            try { r = work(); } catch (Exception) { r = null; }
            ui.BeginInvoke(() => done(r));
        });
    };

    /// <summary>The file dialogs (Import / Export; set by Program, a fake in tests).</summary>
    public IFilePicker? Picker { get; init; }

    /// <summary>Runs an action on the UI thread from background work (a Run's progress; tests run it at once).</summary>
    public Action<Action> Post { get; init; } = System.Windows.Application.Current is { } app
        ? a => app.Dispatcher.BeginInvoke(a)
        : a => a();

    /// <summary>The Catalogue's page (one per run: its cards, queue and bars), made by PageFactory.</summary>
    public Pages.CatalogueView? Catalogue { get; set; }

    /// <summary>The Install AkariOS page (one per run: its mode, step and Selection), made by PageFactory.</summary>
    public Pages.InstallPage? Install { get; set; }

    /// <summary>The update check and install (About, Home's bar, the launch check; none in some tests).</summary>
    public UpdateService? Updates { get; set; }

    /// <summary>Closes the app without asking (an update is starting the new exe); set by Program.</summary>
    public Action Close { get; set; } = () => { };

    /// <summary>The window's step footer (none in some tests).</summary>
    public Pages.StepFooter? Footer { get; set; }

    /// <summary>Where the Catalogue's bars go: the window's CatBars, under the page surface (none in some tests).</summary>
    public System.Windows.Controls.Panel? Bars { get; set; }

    /// <summary>The session's restore point is made, or was declined: not asked again (Get-AkariRestoreChoice).</summary>
    public bool RestoreDone { get; set; }

    /// <summary>Whether the changes about to run get a restore point first (Get-AkariRestoreChoice): Downloads (app
    /// installs only) never; the rest once per session; when an AkariOS restore point exists already, the user
    /// decides. Either way it is not asked again. False when there is no System Restore to ask (tests).</summary>
    public bool RestoreChoice(string flow)
    {
        if (flow == "Downloads" || RestoreDone || Engine.RestorePoints is not { } points) return false;
        if (points.Latest() is { } point)
        {
            var when = point.Date is { } d ? $" on {d:g}" : "";
            if (Dialogs?.Confirm($"AkariOS already made a restore point{when}.\n\nCreate another restore point before these changes?", "Create one", "Skip", "Question", "Restore point") != true)
            {
                RestoreDone = true;
                return false;
            }
        }
        return true;
    }

    /// <summary>The AkariOS preset One-click hands to the console once the window is closed (Program runs it).</summary>
    public Core.Presets.Preset? OneClick { get; private set; }

    public const string OneClickWarning = "AkariOS One-click changes a lot of Windows, including security features.\n\n" +
        "- Run it on a fresh install or a PC you can reinstall. There is no uninstaller.\n" +
        "- Security is reduced on purpose (Defender settings, UAC, memory integrity).\n" +
        "- Your PC restarts several times, once into Safe Mode. Save your work and don't interrupt it.\n" +
        "- Graphics and audio drivers are removed. Install a fresh graphics driver afterwards.\n" +
        "- It is tuned for desktops: power saving is turned off.\n" +
        "- It needs an internet connection.\n\nStart AkariOS One-click now?";

    /// <summary>
    /// One-click (Start-AkariOneClick): asks first, makes the session's restore point here in the window (a refusal asks
    /// to go on without one), then closes the window: its console runs the AkariOS preset's phases.
    /// </summary>
    public void StartOneClick()
    {
        if (Shell.Busy || Install?.Running == true || Catalogue?.Running == true)
        {
            Dialogs?.Message("Wait until the changes running now are done, then start One-click.", "Info", "AkariOS One-click");
            return;
        }
        if (Engine.Presets.Find("AkariOS") is not { } preset)
        {
            Dialogs?.Message("The AkariOS preset is missing from this build.", "Error", "AkariOS One-click");
            return;
        }
        if (Dialogs?.Confirm(OneClickWarning, "Start One-click", "Cancel", "Warning", "AkariOS One-click") != true) return;
        void Go()
        {
            OneClick = preset;
            Log.WriteFile($"One-click started: {preset.Path}");
            Close();
        }
        if (!RestoreChoice("OneClick")) { Go(); return; }
        RestoreDone = true;
        Shell.SetBusy(true, "Creating a restore point");
        Background(() => Engine.RestorePoints!.Create("AkariOS"), r =>
        {
            Shell.SetBusy(false);
            if (r is Core.Runs.RestoreResult { Ok: false } failed && Dialogs?.Confirm(
                    $"AkariOS could not create a restore point:\n\n{failed.Message}\n\nRun AkariOS One-click without a restore point?",
                    "Run anyway", "Cancel", "Warning", "AkariOS One-click") != true)
            {
                Log.Write("One-click cancelled: no restore point.");
                RestoreDone = false;
                return;
            }
            Go();
        });
    }

    /// <summary>A message saying what isn't in the native app yet, and when it comes.</summary>
    public void NotYet(string what, string milestone) =>
        Dialogs?.Message($"{what} isn't in the native app yet: it comes with {milestone} (docs/plans/2026-10-31-native-app.md). The PowerShell app has it today.", "Info", "Not yet");
}
