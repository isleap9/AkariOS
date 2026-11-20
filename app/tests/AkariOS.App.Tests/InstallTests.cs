using AkariOS.App.ViewModels;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using Microsoft.UI.Xaml;

namespace AkariOS.App.Tests;

/// <summary>Install AkariOS (Steps.ps1; the WPF app's InstallPage) on fixture Tweaks: the chooser, Guided's Apps, Tweaks
/// and Review steps, the Run with its restore point, the run page and the result, Quick select, Import, One-click.</summary>
public sealed class InstallTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    // the fixtures, a legacy app removal, an app install, the AkariOS preset
    private AppTest Make() => _h.Make(AppHarness.Fixtures()
        .Add("src/Tweaks/Apps/Remove/Legacy.ps1", """
            # Action: a removal has no Windows default
            @{
                Id = 'fix-legacy'; Name = 'Legacy thing'; Section = 'Apps'; Category = 'Remove'; Kind = 'Action'; Risk = 'Safe'; Description = 'A fixture.'
                Button = 'Remove'
                Apply = { Remove-Thing }
            }
            """)
        .Add("src/Tweaks/Apps/Install/App.ps1", """
            # Action: an install has no Windows default
            @{
                Id = 'fix-app'; Name = 'An app'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; Risk = 'Caution'; Description = 'A fixture.'
                Button = 'Install'; AppType = 'Utilities'; Winget = 'Fix.App'
            }
            """)
        .Add("src/Presets/AkariOS.json", """{ "Name": "AkariOS", "Description": "The setup", "Tweaks": [ "fix-plain", { "fix-pick": 3 } ] }"""));

    private static InstallViewModel Guided(AppTest t)
    {
        var i = t.Install;
        i.Guide();
        return i;
    }

    private static InstallViewModel OnTweaks(AppTest t)
    {
        var i = Guided(t);
        i.NextCommand.Execute(null);
        Assert.True(i.IsTweaks);
        return i;
    }

    [Fact]
    public void Starts_on_the_chooser_and_walks_the_steps()
    {
        var t = Make();
        var i = t.Install;
        Assert.True(i.IsChoosing);
        Assert.Equal(("Install AkariOS", false), (i.Heading, i.ShowFooter));
        i.Guide();
        Assert.Equal(("Apps", "Step 1 of 3 · Apps", "Next"), (i.Heading, i.StepLabel, i.NextText));
        Assert.Equal(["Current", "", ""], i.Stepper.Select(s => s.State));
        i.NextCommand.Execute(null);
        Assert.Equal(("Tweaks", "Review (0)", false), (i.Heading, i.NextText, i.CanNext));
        Assert.Equal(["Done", "Current", ""], i.Stepper.Select(s => s.State));
        i.BackCommand.Execute(null);
        i.BackCommand.Execute(null);
        Assert.True(i.IsChoosing);
        // Back on the chooser: Home
        i.BackCommand.Execute(null);
        Assert.Equal(["Home"], t.Navigated);
    }

    [Fact]
    public void Tweaks_step_reads_the_states_and_picks_into_the_selection()
    {
        var t = Make();
        var i = OnTweaks(t);
        var s = i.Tweaks;
        Assert.False(s.IsReading);
        Assert.Equal(["Optimize", "Customize"], s.Sections.Select(x => x.Section));
        // a Toggle checked = Apply; its card counts it; Review (1)
        s.Rows["fix-plain"].IsChecked = true;
        var p = i.Selection["fix-plain"];
        Assert.Equal((TweakMode.Apply, "Default", "Optimized"), (p.Mode, p.From, p.To));
        Assert.Equal("1 of 5", s.Sections[0].Categories.Single(c => c.Name == "Test").CountText);
        Assert.Equal(("Review (1)", true), (i.NextText, i.CanNext));
        // unchecked again: no change
        s.Rows["fix-plain"].IsChecked = false;
        Assert.Empty(i.Selection);
    }

    [Fact]
    public void A_tweak_that_asks_is_unchecked_when_declined()
    {
        var t = Make();
        var s = OnTweaks(t).Tweaks;
        s.Rows["fix-asking"].IsChecked = true;
        Assert.Equal("Really change it?", Assert.Single(t.Dialogs.Asked));
        Assert.False(s.Rows["fix-asking"].IsChecked);
        Assert.Empty(t.Install.Selection);
        t.Dialogs.Answers.Enqueue("Continue");
        s.Rows["fix-asking"].IsChecked = true;
        Assert.True(t.Install.Selection.ContainsKey("fix-asking"));
    }

    [Fact]
    public void A_choice_starts_on_no_change_and_a_riskier_value_asks()
    {
        var t = Make();
        var row = OnTweaks(t).Tweaks.Rows["fix-pick"];
        Assert.Equal(["No change", "One (Recommended)", "Two (Windows default)", "Three"], row.Choices.Select(c => c.Label));
        Assert.Same(row.Choices[0], row.SelectedChoice);
        row.SelectedChoice = row.Choices[3];
        Assert.Contains("'Three' is marked Advanced", Assert.Single(t.Dialogs.Asked));
        Assert.Same(row.Choices[0], row.SelectedChoice);
        row.SelectedChoice = row.Choices[1];
        var p = t.Install.Selection["fix-pick"];
        Assert.Equal((TweakMode.Apply, "One", false), (p.Mode, p.To, p.HasValue));
        row.SelectedChoice = row.Choices[0];
        Assert.Empty(t.Install.Selection);
    }

    [Fact]
    public void Show_current_state_starts_applied_tweaks_checked()
    {
        var t = Make();
        t.Engine.Registry.SetValue(@"HKCU:\Software\AkariFix", "Plain", 1, "DWord");
        var s = OnTweaks(t).Tweaks;
        Assert.True(s.Rows["fix-plain"].IsChecked);
        // unchecking an applied one reverts it
        s.Rows["fix-plain"].IsChecked = false;
        Assert.Equal(TweakMode.Revert, t.Install.Selection["fix-plain"].Mode);
        s.UseState = false;
        Assert.False(s.Rows["fix-plain"].IsChecked);
        Assert.Empty(t.Install.Selection);
    }

    [Fact]
    public void Filter_hides_rows_cards_and_sections_and_columns_follow_the_width()
    {
        var t = Make();
        var s = OnTweaks(t).Tweaks;
        s.Query = "dark";
        Assert.Equal(Visibility.Collapsed, s.Rows["fix-plain"].Shows);
        Assert.Equal([Visibility.Collapsed, Visibility.Visible], s.Sections.Select(x => x.Shows));
        s.Query = "";
        s.SetColumns(2);
        Assert.Equal(0, s.Sections[0].ThirdWidth.Value);
        Assert.Equal(2, s.Sections[0].Column0.Count + s.Sections[0].Column1.Count);
        s.SetColumns(3);
        Assert.Equal(GridUnitType.Star, s.Sections[0].ThirdWidth.GridUnitType);
    }

    [Fact]
    public void An_editable_choice_takes_a_typed_number()
    {
        var t = _h.Make(AppHarness.Fixtures().Add("src/Tweaks/Advanced/Tuning/Typed.ps1", """
            @{
                Id = 'fix-typed'; Name = 'Typed'; Section = 'Advanced'; Category = 'Tuning'; Kind = 'Choice'; Risk = 'Safe'; Description = 'A fixture.'
                Registry = @{ Path = 'HKCU:\Software\AkariFix'; Name = 'Typed'; Type = 'DWord' }
                Choices = @( @{ Value = 2; Label = 'Two' }, @{ Value = 38; Label = 'Games' } )
                Recommended = 38
                Default = 2
                Editable = $true
            }
            """));
        var row = OnTweaks(t).Tweaks.Rows["fix-typed"];
        Assert.True(row.Type("0x28"));
        Assert.Equal("40 (typed)", ((ChoiceItem)row.SelectedChoice!).Label);
        Assert.Equal((40u, true), (t.Install.Selection["fix-typed"].Value, t.Install.Selection["fix-typed"].HasValue));
        Assert.False(row.Type("lots"));
        Assert.Equal("40 (typed)", ((ChoiceItem)row.SelectedChoice!).Label);
    }

    [Fact]
    public void Apps_step_lists_removals_and_installs_and_picks_into_the_selection()
    {
        var t = Make();
        var a = Guided(t).Apps;
        Assert.False(a.IsReading);
        Assert.Equal(["Store apps (0)", "Optional features (0)", "Windows features (0)", "Legacy apps (1)"], a.RemoveTables.Select(x => x.Title));
        Assert.True(a.FeaturesRead);
        Assert.Equal(["Utilities (1)", "Restore removed apps (0)"], a.InstallTables.Select(x => x.Title));
        Assert.True(a.Rows["fix-app"].IsCautionInstall);
        a.SelectRecommendedCommand.Execute(null);
        Assert.True(a.Rows["fix-legacy"].IsChecked);
        a.Rows["fix-app"].IsChecked = true;
        Assert.Equal("1 to remove, 1 to install", a.StatusText);
        a.ClearRemovalsCommand.Execute(null);
        Assert.Equal(["fix-app"], t.Install.Selection.Keys);
    }

    [Fact]
    public void Review_groups_the_changes_and_warns_about_a_restart()
    {
        var t = Make();
        var i = Guided(t);
        i.Apps.Rows["fix-legacy"].IsChecked = true;
        i.NextCommand.Execute(null);
        i.Tweaks.Rows["fix-plain"].IsChecked = true;
        i.Tweaks.Rows["fix-reboots"].IsChecked = true;
        i.NextCommand.Execute(null);
        Assert.True(i.IsReview);
        Assert.Equal(("1", "0", "2"), (i.RemoveCount, i.InstallCount, i.TweakCount));
        Assert.Equal(["Remove", "Install", "Tweaks"], i.Review.Select(g => g.Title));
        Assert.Equal(["Legacy thing"], i.Review[0].Rows.Select(r => r.Name));
        Assert.Equal("Default → Optimized", i.Review[2].Rows[0].Line);
        Assert.Equal("", i.RestartNote);
        Assert.Equal("Apply 3 changes", i.NextText);
    }

    [Fact]
    public async Task Apply_runs_after_a_restore_point_and_shows_the_result()
    {
        var t = Make();
        var i = OnTweaks(t);
        i.Tweaks.Rows["fix-plain"].IsChecked = true;
        i.Tweaks.Rows["fix-pick"].SelectedChoice = i.Tweaks.Rows["fix-pick"].Choices[1];
        i.NextCommand.Execute(null);
        await i.NextCommand.ExecuteAsync(null);
        Assert.True(i.IsResult);
        Assert.Equal((1u, 1u), (t.Fix("Plain"), t.Fix("Pick")));
        Assert.Single(t.Points.Points);
        Assert.Equal(["Create a restore point", "Plain", "Pick"], i.RunItems.Select(r => r.Name));
        Assert.All(i.RunItems, r => Assert.Equal(RunState.Applied, r.State));
        Assert.Equal(("2 changes applied", "Everything went through.", "2", "0"), (i.ResultTitle, i.ResultText, i.OkCount, i.BadCount));
        // Explorer once; Recent activity; Last used; the shell free again
        Assert.Equal(1, t.Explorer.Restarts);
        Assert.Equal("Guided run", t.Activity.All()[0].Title);
        Assert.Equal(["fix-plain", "fix-pick"], t.Engine.Presets.LastUsed()!.Entries.Select(e => e.Id));
        Assert.False(t.Shell.Locked || t.Shell.IsBusy);
        // Done: the chooser, Home
        i.DoneCommand.Execute(null);
        Assert.True(i.IsChoosing);
        Assert.Empty(i.Selection);
        Assert.Equal("Home", t.Navigated[^1]);
    }

    [Fact]
    public async Task A_refused_restore_point_asks_before_going_on_without_one()
    {
        var t = Make();
        t.Points.Refuse = true;
        var i = OnTweaks(t);
        i.Tweaks.Rows["fix-plain"].IsChecked = true;
        i.NextCommand.Execute(null);
        // Cancel: back on Review, nothing changed
        await i.ApplyAsync();
        Assert.True(i.IsReview);
        Assert.Null(t.Fix("Plain"));
        Assert.Contains("could not create a restore point", t.Dialogs.Asked[^1]);
        t.Dialogs.Answers.Enqueue("Apply anyway");
        await i.ApplyAsync();
        Assert.True(i.IsResult);
        Assert.Equal(1u, t.Fix("Plain"));
        // the session's restore point is settled: the next Run doesn't try again
        Assert.True(t.Restore.Done);
    }

    [Fact]
    public async Task While_a_run_applies_the_catalogue_waits_and_closing_asks()
    {
        var t = Make();
        var i = OnTweaks(t);
        i.Tweaks.Rows["fix-plain"].IsChecked = true;
        i.NextCommand.Execute(null);
        t.Work.Hold = true;
        await i.ApplyAsync();
        Assert.True(i.IsRun);
        Assert.True(t.Shell.Locked);
        Assert.Equal(RunState.Working, i.RunItems[0].State);
        // Optimize's cards wait
        t.Work.Hold = false;
        await t.Catalogue.ChangeAsync(t.Engine.Find("fix-dark")!, TweakMode.Apply);
        Assert.Contains("Install AkariOS is applying changes", t.Dialogs.Asked[^1]);
        Assert.Null(t.Fix("Dark"));
        Assert.False(await i.CanCloseAsync());
        while (t.Work.Held.TryDequeue(out var run)) run();
        Assert.True(i.IsResult);
        Assert.True(await i.CanCloseAsync());
    }

    [Fact]
    public void Quick_select_replaces_the_picks_and_saves_presets()
    {
        var t = Make();
        var i = OnTweaks(t);
        i.Tweaks.Rows["fix-dark"].IsChecked = true;
        var akari = i.Tweaks.Presets().Single(p => p.Builtin);
        Assert.Equal("AkariOS (recommended)", TweaksStepViewModel.PresetLabel(akari));
        i.QuickSelect(akari);
        Assert.Equal(["fix-plain", "fix-pick"], i.Selection.Keys);
        Assert.True(i.Tweaks.Rows["fix-plain"].IsChecked);
        Assert.Equal("Three", ((ChoiceItem)i.Tweaks.Rows["fix-pick"].SelectedChoice!).Label);
        // saved under the name asked for: Quick select lists it
        t.Names.Enqueue("Mine");
        i.Tweaks.SavePresetCommand.Execute(null);
        Assert.Contains(i.Tweaks.Presets(), p => p.Name == "Mine" && !p.Builtin);
    }

    [Fact]
    public async Task Import_opens_guided_tweaks_with_the_files_changes()
    {
        var t = Make();
        var file = Path.Combine(_h.Dir, "exported.json");
        File.WriteAllText(file, """{ "Name": "PC", "Tweaks": [ "fix-dark" ] }""");
        t.Picker.OpenPath = file;
        await t.Install.ImportAsync();
        Assert.Equal(("Guided", 1), (t.Install.Mode, t.Install.Step));
        Assert.Equal(["fix-dark"], t.Install.Selection.Keys);
        Assert.Equal("Install AkariOS", t.Navigated[^1]);
        Assert.True(File.Exists(Path.Combine(t.Engine.Presets.UserFolder, "exported.json")));
        // a file with no settings says so
        File.WriteAllText(file, "{}");
        await t.Install.ImportAsync();
        Assert.Contains("no AkariOS settings", t.Dialogs.Asked[^1]);
    }

    [Fact]
    public async Task One_click_asks_makes_the_restore_point_and_hands_the_preset_over()
    {
        var t = Make();
        await t.Install.StartOneClickAsync();
        Assert.Contains("There is no uninstaller", t.Dialogs.Asked[^1]);
        Assert.Empty(t.OneClicks);
        t.Dialogs.Answers.Enqueue("Start One-click");
        await t.Install.StartOneClickAsync();
        Assert.Equal("AkariOS", Assert.Single(t.OneClicks).Name);
        Assert.Single(t.Points.Points);
        Assert.False(t.Shell.IsBusy);
    }
}
