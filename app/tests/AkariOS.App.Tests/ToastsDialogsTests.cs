using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.Core.Runs;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Tests;

/// <summary>W6: the busy toast's progress, the result toasts, Akari's dialog text and the closing question.</summary>
public sealed class ToastsDialogsTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    [Fact]
    public void The_busy_toast_shows_the_latest_work_and_its_progress()
    {
        var s = new ShellState();
        var a = s.Begin("Installing PuTTY");
        Assert.Equal((true, "Installing PuTTY", true), (s.IsBusy, s.BusyText, s.Indeterminate));
        var b = s.Begin("Applying 4 changes");
        s.Report(b, new RunProgress(1, 4, "Plain"));
        Assert.Equal(("Applying 4 changes (2 of 4): Plain", false, 25d), (s.BusyText, s.Indeterminate, s.ProgressValue));
        // the latest one ends: the one before it shows again
        s.End(b);
        s.End(b);
        Assert.Equal(("Installing PuTTY", true), (s.BusyText, s.Indeterminate));
        Assert.Equal(["Installing PuTTY"], s.Work.Select(w => w.Label));
        s.End(a);
        Assert.Equal((false, ""), (s.IsBusy, s.BusyText));
    }

    [Fact]
    public void Progress_text_is_get_akari_progress_text()
    {
        Assert.Equal("Removing", ShellState.ProgressText("Removing", 3, 0, "x"));
        Assert.Equal("Removing 2 apps (2 of 2)", ShellState.ProgressText("Removing 2 apps", 5, 2, ""));
        Assert.Equal("Removing 2 apps (1 of 2): Xbox", ShellState.ProgressText("Removing 2 apps", 0, 2, "Xbox"));
    }

    [Fact]
    public void Toasts_stack_newest_first_and_drop_the_oldest()
    {
        var s = new ShellState();
        for (var i = 1; i <= ShellState.MaxToasts + 1; i++) s.Toast($"T{i}");
        Assert.Equal(["T5", "T4", "T3", "T2"], s.Toasts.Select(t => t.Title));
        s.Toasts[0].CloseCommand.Execute(null);
        Assert.Equal("T4", s.Toasts[0].Title);
        // an action: longer on screen, closed when used
        var acted = 0;
        var x = s.Toast("Exported", "here", InfoBarSeverity.Success, "Open folder", () => acted++);
        Assert.Equal((true, 10), (x.HasAction, x.Seconds));
        Assert.Equal((false, 5), (s.Toasts[1].HasAction, s.Toasts[1].Seconds));
        x.ActCommand.Execute(null);
        Assert.Equal(1, acted);
        Assert.DoesNotContain(x, s.Toasts);
        Assert.Equal(10, s.Toast("Failed", "", InfoBarSeverity.Error).Seconds);
    }

    [Fact]
    public void Dialog_text_turns_dash_lines_into_a_list()
    {
        Assert.Equal(
            [new DialogBlock(false, "AkariOS changes a lot."), new DialogBlock(true, "No uninstaller."), new DialogBlock(true, "Restarts."), new DialogBlock(false, "Go on?")],
            DialogText.Blocks("AkariOS changes a lot.\r\n\n- No uninstaller.\n•  Restarts.\n\n  Go on?  "));
        // a dash with no space after it is text
        Assert.Equal([new DialogBlock(false, "-1 change")], DialogText.Blocks("-1 change"));
        // One-click's warning: one paragraph, six consequences
        var blocks = DialogText.Blocks(InstallViewModel.OneClickWarning);
        Assert.Equal((1, 6), (blocks.Count(b => !b.Item), blocks.Count(b => b.Item)));
    }

    [Fact]
    public async Task Closing_asks_once_naming_everything_running()
    {
        var t = _h.Make(AppHarness.Fixtures());
        Assert.False(t.Closing.MustAsk);
        Assert.True(await t.Closing.CanCloseAsync());
        Assert.Empty(t.Dialogs.Asked);

        // a change from Optimize running, one waiting behind it
        t.Restore.Done = true;
        t.Work.Hold = true;
        t.Card("fix-plain").IsOn = true;
        t.Card("fix-dark").IsOn = true;
        Assert.True(t.Closing.MustAsk);
        Assert.Equal(["Plain: apply", "1 change from Optimize waiting"], t.Closing.Running());
        Assert.False(await t.Closing.CanCloseAsync());
        Assert.Equal("These are still running:\n- Plain: apply\n- 1 change from Optimize waiting\n\nClose AkariOS anyway? What is running may be left half done, and what waits won't run.",
            Assert.Single(t.Dialogs.Asked));
        t.Dialogs.Answers.Enqueue("Close anyway");
        Assert.True(await t.Closing.CanCloseAsync());
        t.Work.Hold = false;
        while (t.Work.Held.TryDequeue(out var run)) run();
        Assert.Equal((1u, 1u), (t.Fix("Plain"), t.Fix("Dark")));
        Assert.False(t.Closing.MustAsk);
    }

    [Fact]
    public async Task Safe_mode_changes_waiting_ask_after_nothing_runs()
    {
        var t = _h.Make(AppHarness.Fixtures());
        t.Dialogs.Answers.Enqueue("Later");
        t.Card("fix-safe").IsOn = true;
        Assert.True(t.Closing.MustAsk);
        Assert.Empty(t.Closing.Running());
        t.Dialogs.Answers.Enqueue("Discard");
        Assert.True(await t.Closing.CanCloseAsync());
        Assert.StartsWith("1 change is waiting for Safe Mode.", t.Dialogs.Asked[^1]);
    }

    [Fact]
    public async Task Restart_and_apply_from_the_safe_mode_question_runs_at_once()
    {
        var t = _h.Make(AppHarness.Fixtures());
        t.Dialogs.Answers.Enqueue("Restart and apply");
        await t.Catalogue.ChangeAsync(t.Engine.Find("fix-safe")!, Core.Tweaks.TweakMode.Apply);
        // asked once (no second "Restart now?"), then the Run in phases restarts into Safe Mode
        Assert.Single(t.Dialogs.Asked);
        Assert.Equal(["next SafeMode", "restart 5"], t.Boot.Steps);
        Assert.Empty(t.Catalogue.SafePending);
    }

    [Fact]
    public async Task Remove_apps_counts_its_progress_and_says_how_it_went_in_a_toast()
    {
        var t = _h.Make();
        t.Packages.Add("Microsoft.WindowsAlarms", "Microsoft.BingNews");
        var r = t.Remove;
        r.Shown();
        r.Apps.Rows["appx/Microsoft.WindowsAlarms"].IsChecked = true;
        r.Apps.Rows["appx/Microsoft.BingNews"].IsChecked = true;
        t.Restore.Done = true;
        var seen = new List<string>();
        t.Shell.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ShellState.BusyText) && t.Shell.BusyText.Length > 0) seen.Add(t.Shell.BusyText);
        };
        t.Dialogs.Answers.Enqueue("Remove");
        await r.RemoveAsync();
        Assert.Equal("Removing 2 apps", seen[0]);
        Assert.Contains(seen, x => x.StartsWith("Removing 2 apps (2 of 2)", StringComparison.Ordinal));
        Assert.Equal("Removed: 2 apps are gone.", t.Toasts[0]);
        Assert.Equal(InfoBarSeverity.Success, t.Shell.Toasts[0].Severity);
    }

    [Fact]
    public async Task A_queued_install_waits_for_a_locked_run_and_starts_after_it()
    {
        var t = _h.Make();
        var d = t.Downloads;
        d.Open();
        t.Shell.Locked = true;
        d.Cards["install-putty"].InstallCommand.Execute(null);
        Assert.Equal(CardState.Waiting, d.Cards["install-putty"].State);
        Assert.Equal(["1 app waiting to install"], t.Closing.Running());
        t.Shell.Locked = false;
        Assert.Equal(CardState.Installed, d.Cards["install-putty"].State);
        Assert.Equal("PuTTY is installed", t.Toasts[0]);
        Assert.False(t.Closing.MustAsk);
        await Task.CompletedTask;
    }
}
