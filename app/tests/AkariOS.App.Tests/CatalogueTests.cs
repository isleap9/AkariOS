using AkariOS.Core.Tweaks;

namespace AkariOS.App.Tests;

/// <summary>Optimize's pages and changes (CatalogueViewModel, CataloguePageViewModel) on fixture Tweaks.</summary>
public sealed class CatalogueTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private AppTest Make(bool safeMode = false) => _h.Make(AppHarness.Fixtures(), safeMode);

    // ---- pages

    [Fact]
    public void A_section_page_lists_its_categories_and_a_category_page_its_cards_with_their_states()
    {
        var t = Make();
        var page = t.Page("Catalogue:Optimize");
        Assert.Equal("Optimize", page.Title);
        Assert.Equal([("Other", 1), ("Test", 5)], page.Categories.Select(c => (c.Name, c.Count)));
        Assert.Empty(page.Groups);
        Assert.False(page.HasCards);
        var test = t.Page("Catalogue:Optimize/Test");
        Assert.Equal(["fix-asking", "fix-pick", "fix-plain", "fix-reboots", "fix-safe"], test.Groups.Single().Cards.Select(c => c.Id).Order());
        Assert.Equal("5 tweaks", test.CountText);
        t.Page("Catalogue:Optimize/Other");
        Assert.Equal("Windows default", t.Card("fix-plain").StateLine);
        Assert.False(t.Card("fix-plain").IsOn);
        // an Action has no State line at rest
        Assert.Equal(("", true, "Open"), (t.Card("fix-run").StateLine, t.Card("fix-run").IsAction, t.Card("fix-run").ButtonText));
    }

    [Fact]
    public void A_category_page_shows_only_its_cards()
    {
        var page = Make().Page("Catalogue:Optimize/Test");
        Assert.Equal(("Test", 1), (page.Title, page.Groups.Count));
        Assert.Equal(["Optimize", "Optimize", "Test"], page.Crumbs);
    }

    [Fact]
    public void The_hardware_section_is_headed_graphics_and_hardware()
    {
        Assert.Equal("Graphics & Hardware", Make().Page("Catalogue:Hardware").Title);
    }

    [Fact]
    public void A_choice_lists_its_values_noting_recommended_and_windows_default()
    {
        var c = Make().Card("fix-pick");
        Assert.Equal(["One (Recommended)", "Two (Windows default)", "Three"], c.Choices.Select(x => x.Label));
        Assert.Null(c.SelectedChoice);
    }

    [Fact]
    public void Risk_badges()
    {
        var t = Make();
        Assert.Equal((true, "Caution"), (t.Card("fix-dark").HasRiskBadge, t.Card("fix-dark").RiskBadge));
        Assert.False(t.Card("fix-plain").HasRiskBadge);
    }

    [Fact]
    public void The_search_heads_each_category_and_says_when_nothing_matches()
    {
        var t = Make();
        var page = t.Page("", "fixture");
        Assert.True(page.IsSearch);
        Assert.Equal(["Optimize › Test", "Customize › Look"], page.Groups.Select(g => g.Title));
        var none = t.Page("", "zzz");
        Assert.Equal((true, "No tweak matches."), (none.IsEmpty, none.EmptyText));
    }

    [Fact]
    public void Suggestions_are_at_most_six()
    {
        var t = Make();
        Assert.Equal(6, t.Catalogue.Suggest("fixture").Count);
        Assert.Empty(t.Catalogue.Suggest("  "));
        Assert.Equal(["fix-run"], t.Catalogue.Suggest("action").Select(x => x.Id));
    }

    [Fact]
    public void Refresh_reads_the_states_again_and_cards_are_kept()
    {
        var t = Make();
        var page = t.Page("Catalogue:Optimize/Test");
        var card = t.Card("fix-plain");
        t.Engine.Registry.SetValue(@"HKCU:\Software\AkariFix", "Plain", 1u, "DWord");
        Assert.Equal("Windows default", card.StateLine);
        page.Refresh();
        Assert.Equal(("Optimized", true), (card.StateLine, card.IsOn));
        Assert.Same(card, t.Page("Catalogue:Optimize/Test").Groups[0].Cards.First(c => c.Id == "fix-plain"));
    }

    // ---- changes

    [Fact]
    public void A_switch_applies_and_reverts_right_away_after_one_restore_point()
    {
        var t = Make();
        t.Page("Catalogue:Optimize/Test");
        var c = t.Card("fix-plain");
        c.IsOn = true;
        Assert.Equal((1u, "Optimized", true), (t.Fix("Plain"), c.StateLine, c.IsOn));
        c.IsOn = false;
        Assert.Equal((null, "Windows default"), (t.Fix("Plain"), c.StateLine));
        // the session's first change made the restore point; nothing asked
        Assert.Equal(["AkariOS"], t.Points.Points.Select(p => p.Description));
        Assert.Empty(t.Dialogs.Asked);
        Assert.Equal((false, false), (t.Shell.IsBusy, t.Catalogue.Running));

        // Explorer = $true: the restart bar offers Explorer's restart, which clears it
        Assert.Equal((true, "Explorer needs a restart to show 1 change.", true, false),
            (t.Catalogue.RestartBarOpen, t.Catalogue.RestartBarText, t.Catalogue.CanRestartExplorer, t.Catalogue.CanRestartPc));
        t.Catalogue.RestartExplorer();
        Assert.Equal((1, false), (t.Explorer.Restarts, t.Catalogue.RestartBarOpen));
    }

    [Fact]
    public void An_akarios_restore_point_from_before_asks_and_skip_means_none_this_session()
    {
        var t = Make();
        t.Points.Points.Add(new("AkariOS", new DateTime(2026, 10, 1, 9, 30, 0), 7));
        t.Dialogs.Answers.Enqueue("Skip");
        t.Card("fix-plain").IsOn = true;
        t.Card("fix-reboots").IsOn = true;
        Assert.Single(t.Dialogs.Asked);
        Assert.StartsWith("AkariOS already made a restore point on ", t.Dialogs.Asked[0]);
        Assert.Single(t.Points.Points);
        Assert.Equal(1u, t.Fix("Reboots"));
    }

    [Fact]
    public void A_confirm_text_asks_first_and_cancel_changes_nothing()
    {
        var t = Make();
        var c = t.Card("fix-asking");
        c.IsOn = true;
        Assert.Equal(["Really change it?"], t.Dialogs.Asked);
        // the switch goes back
        Assert.Equal((null, false), (t.Fix("Asking"), c.IsOn));
        t.Dialogs.Answers.Enqueue("Continue");
        c.IsOn = true;
        Assert.Equal(1u, t.Fix("Asking"));
        // going back to the Windows default never asks
        c.IsOn = false;
        Assert.Equal((2, (object?)null), (t.Dialogs.Asked.Count, t.Fix("Asking")));

        // a Choice value riskier than its Tweak asks; its Default doesn't
        var pick = t.Card("fix-pick");
        pick.SelectedChoice = pick.Choices[2];
        Assert.Equal("Pick: 'Three' is marked Advanced. Select it anyway?", t.Dialogs.Asked[^1]);
        Assert.Null(t.Fix("Pick"));
        Assert.Null(pick.SelectedChoice);
        pick.SelectedChoice = pick.Choices[1];
        Assert.Equal((3, 2u), (t.Dialogs.Asked.Count, t.Fix("Pick")));
        Assert.Same(pick.Choices[1], pick.SelectedChoice);
    }

    [Fact]
    public void A_choice_applies_the_value_picked()
    {
        var t = Make();
        var pick = t.Card("fix-pick");
        pick.SelectedChoice = pick.Choices[0];
        Assert.Equal((1u, "Optimized"), (t.Fix("Pick"), pick.StateLine));
    }

    [Fact]
    public async Task A_safe_mode_tweak_waits_in_its_bar_and_closing_asks()
    {
        var t = Make();
        t.Page("Catalogue:Optimize/Test");
        var c = t.Card("fix-safe");
        // asked first: Cancel switches it back
        c.IsOn = true;
        Assert.StartsWith("A fixture.\n\nThis change applies in Safe Mode", t.Dialogs.Asked[^1]);
        Assert.Equal((false, 0), (c.IsOn, t.Catalogue.SafePending.Count));
        t.Dialogs.Asked.Clear();
        // Later: it waits, a toast says so
        t.Dialogs.Answers.Enqueue("Later");
        c.IsOn = true;
        t.Dialogs.Asked.Clear();
        Assert.Equal("Waiting for Safe Mode: \"Safe\" applies the next time AkariOS restarts into Safe Mode.", t.Toasts[0]);
        Assert.Equal((null, "Waiting for Safe Mode", true, true), (t.Fix("Safe"), c.StateLine, c.IsOn, c.ShowWarnLine));
        Assert.Equal((true, "1 change needs Safe Mode: Akari restarts into it, applies them and restarts back."), (t.Catalogue.SafeBarOpen, t.Catalogue.SafeBarText));
        Assert.True(t.Catalogue.MustAsk);

        // closing: Discard closes; "Restart and apply" then Cancel keeps the window open and nothing runs
        t.Dialogs.Answers.Enqueue("Discard");
        Assert.True(await t.Catalogue.CanCloseAsync());
        Assert.StartsWith("1 change is waiting for Safe Mode.", t.Dialogs.Asked[0]);
        t.Dialogs.Answers.Enqueue("Restart and apply");
        Assert.False(await t.Catalogue.CanCloseAsync());
        Assert.StartsWith("AkariOS restarts into Safe Mode now", t.Dialogs.Asked[^1]);
        Assert.Empty(t.Boot.Steps);

        // switched back before the restart: nothing waits
        c.IsOn = false;
        Assert.Empty(t.Catalogue.SafePending);
        Assert.Equal(("Windows default", false), (c.StateLine, t.Catalogue.SafeBarOpen));
    }

    [Fact]
    public async Task Restart_and_apply_restarts_into_safe_mode_for_the_waiting_changes()
    {
        var t = Make();
        t.Dialogs.Answers.Enqueue("Later");
        t.Card("fix-safe").IsOn = true;
        t.Dialogs.Answers.Enqueue("Restart now");
        await t.Catalogue.SafeRunAsync();
        Assert.StartsWith("AkariOS restarts into Safe Mode now to apply 1 change, then back to normal.", t.Dialogs.Asked[^1]);
        // the session's restore point first, then the Run: run.json, the next boot, the restart
        Assert.Single(t.Points.Points);
        Assert.Equal(["next SafeMode", "restart 5"], t.Boot.Steps);
        var run = t.Runs.Get()!;
        Assert.Equal(["Safe Mode/SafeMode/Apply fix-safe", "Back to normal/Normal/"],
            run.Phases.Select(p => $"{p.Name}/{p.Boot}/{string.Join(",", p.Items.Select(i => $"{i.Mode} {i.Id}"))}"));
        Assert.Empty(t.Catalogue.SafePending);
        Assert.Null(t.Fix("Safe"));
    }

    [Fact]
    public void In_safe_mode_a_safe_mode_tweak_runs_now()
    {
        var t = Make(safeMode: true);
        t.Card("fix-safe").IsOn = true;
        Assert.Equal(1u, t.Fix("Safe"));
        Assert.Empty(t.Catalogue.SafePending);
    }

    [Fact]
    public async Task Restart_now_asks_then_restarts_the_pc()
    {
        var t = Make();
        t.Card("fix-reboots").IsOn = true;
        Assert.True(t.Catalogue.CanRestartPc);
        await t.Catalogue.RestartPcAsync();
        Assert.Equal(0, t.Shutdown.Restarts);
        t.Dialogs.Answers.Enqueue("Restart now");
        await t.Catalogue.RestartPcAsync();
        Assert.Equal((1, "Restart the PC now? Save your work first."), (t.Shutdown.Restarts, t.Dialogs.Asked[^1]));
    }

    [Fact]
    public void An_action_runs_without_a_restore_point()
    {
        var t = Make();
        var run = t.Card("fix-run");
        run.RunCommand.Execute(null);
        // no C# class behind its Apply block in the test: the native app can't run it yet
        Assert.False(run.IsEnabled);
        Assert.Empty(t.Points.Points);
    }

    [Fact]
    public void Changes_queue_one_at_a_time()
    {
        var t = Make();
        t.Page("Catalogue:Optimize/Test");
        t.Work.Hold = true;
        var (plain, reboots) = (t.Card("fix-plain"), t.Card("fix-reboots"));
        plain.IsOn = true;
        reboots.IsOn = true;
        Assert.Equal(("Applying…", "Waiting…", false), (plain.StateLine, reboots.StateLine, reboots.IsEnabled));
        Assert.Equal(("Plain: apply", true), (t.Shell.BusyText, t.Shell.IsBusy));
        Assert.Single(t.Work.Held);
        t.Work.Held.Dequeue()();
        Assert.Equal(("Optimized", "Applying…"), (plain.StateLine, reboots.StateLine));
        t.Work.Held.Dequeue()();
        Assert.Equal(("Optimized", false), (reboots.StateLine, t.Shell.IsBusy));
        Assert.Equal((1u, 1u), (t.Fix("Plain"), t.Fix("Reboots")));
    }
}
