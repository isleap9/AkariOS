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

    /// <summary>A message saying what isn't in the native app yet, and when it comes.</summary>
    public void NotYet(string what, string milestone) =>
        Dialogs?.Message($"{what} isn't in the native app yet: it comes with {milestone} (docs/plans/2026-10-31-native-app.md). The PowerShell app has it today.", "Info", "Not yet");
}

/// <summary>The Catalogue's Tweaks (Get-AkariCatalogueTweaks): one-file Toggles, Choices and Actions this PC meets, no
/// Entries, not Apps or OneClick. N3 builds the Catalogue's pages on them; Home counts them.</summary>
public static class Catalogue
{
    public static IReadOnlyList<Tweak> Tweaks(IEnumerable<Tweak> loaded, ISystemInfo pc) =>
        loaded.Where(t => t.Group is null && t.EntryKind is null && t.Section is not ("Apps" or "OneClick")
            && t.Kind is TweakKind.Toggle or TweakKind.Choice or TweakKind.Action && Requirements.Check(t, pc) is null).ToList();
}
