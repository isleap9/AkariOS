using AkariOS.App.ViewModels;
using AkariOS.Framework.Services;

namespace AkariOS.App.Shell;

/// <summary>
/// Closing the window while something still runs (Shell.ps1's closing question): one question naming everything that
/// runs or waits (every page's busy work, Downloads' and Optimize's queues), then, with nothing running, the Safe Mode
/// changes still waiting (Restart and apply / Discard).
/// </summary>
public sealed class ClosingGuard(ShellState shell, DownloadsViewModel downloads, CatalogueViewModel catalogue, IDialogService dialogs)
{
    /// <summary>Whether closing has to ask first.</summary>
    public bool MustAsk => Running().Count > 0 || catalogue.MustAsk;

    /// <summary>What runs or waits now, one line each.</summary>
    public IReadOnlyList<string> Running()
    {
        var lines = shell.Work.Select(w => w.Label).ToList();
        if (downloads.Waiting is var d and > 0) lines.Add($"{d} app{(d == 1 ? "" : "s")} waiting to install");
        if (catalogue.Queued is var c and > 0) lines.Add($"{c} change{(c == 1 ? "" : "s")} from Optimize waiting");
        return lines;
    }

    public static string Question(IReadOnlyList<string> running) =>
        "These are still running:\n" + string.Join("\n", running.Select(r => $"- {r}")) +
        "\n\nClose AkariOS anyway? What is running may be left half done, and what waits won't run.";

    /// <summary>The window is closing: false keeps it open.</summary>
    public async Task<bool> CanCloseAsync()
    {
        var running = Running();
        if (running.Count > 0) return await dialogs.ConfirmAsync("Close AkariOS?", Question(running), "Close anyway", "Wait");
        return await catalogue.CanCloseAsync();
    }
}
