using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.Core.Update;
using AkariOS.Framework.Services;

namespace AkariOS.App.Tests;

/// <summary>Home (Pages.ps1) and Settings (About.ps1) on fixture Tweaks: the hero's facts, Quick settings, Recent
/// activity, the update InfoBar and prompt, the accent, Export. GitHub, the download and the new exe are faked.</summary>
public sealed class HomeSettingsTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private sealed class Theme : IThemeService
    {
        public AppTheme CurrentTheme { get; private set; } = AppTheme.System;
        public Task InitializeAsync() => Task.CompletedTask;
        public Task SetThemeAsync(AppTheme theme) { CurrentTheme = theme; return Task.CompletedTask; }
        public void Toggle() { }
        public Task SetSystemThemeAsync() => SetThemeAsync(AppTheme.System);
    }

    private sealed class Settings : ISettingsService
    {
        public Dictionary<string, object?> Values { get; } = [];
        public Task<T?> GetAsync<T>(string key, T? defaultValue = default) => Task.FromResult(Values.TryGetValue(key, out var v) ? (T?)v : defaultValue);
        public Task SetAsync<T>(string key, T value) { Values[key] = value; return Task.CompletedTask; }
        public Task RemoveAsync(string key) { Values.Remove(key); return Task.CompletedTask; }
    }

    // a fixture "Quick settings" Tweak: Home lists the ones it knows that this PC has
    private AppTest Make() => _h.Make(AppHarness.Fixtures().Add("src/Tweaks/Optimize/Gaming/GameDvr.ps1", """
        @{
            Id = 'disable-game-dvr'; Name = 'Game DVR off'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'A fixture.'
            Registry = @( @{ Path = 'HKCU:\Software\AkariFix'; Name = 'Dvr'; Type = 'DWord'; Value = 0; Default = $null } )
        }
        """));

    // ---- Home

    [Fact]
    public void Home_states_its_facts_and_opens_the_pages()
    {
        var t = Make();
        var home = t.Home();
        Assert.Equal(t.Catalogue.Tweaks.Count, home.Stats.Tweaks);
        // no Store apps on the test PC, none applied yet
        Assert.Equal(("0", "0"), (home.Stats.AppsText, home.Stats.AppliedText));
        // One-click asks for the AkariOS preset, which the fixtures don't have
        home.OneClickCommand.Execute(null);
        Assert.Equal("The AkariOS preset is missing from this build.", Assert.Single(t.Dialogs.Asked));
        // Choose changes: Install AkariOS on Guided's first step
        home.ChooseChangesCommand.Execute(null);
        home.OptimizeCommand.Execute(null);
        Assert.Equal(["Install AkariOS", "Optimize"], t.Navigated);
        Assert.Equal(("Guided", 0), (t.Install.Mode, t.Install.Step));
    }

    [Fact]
    public void Quick_settings_are_the_catalogues_cards_and_act_right_away()
    {
        var t = Make();
        var home = t.Home();
        var dvr = Assert.Single(home.QuickSettings);
        Assert.Same(t.Card("disable-game-dvr"), dvr);
        Assert.Equal("Windows default", dvr.StateLine);
        dvr.IsOn = true;
        Assert.Equal(0u, t.Fix("Dvr"));
        // it is in Recent activity, and Home's "changes applied" is read again
        Assert.Equal("Applied \"Game DVR off\"", home.Activity[0].Title);
        Assert.Equal("Just now · Optimize", t.Home(DateTime.Now).Activity[0].Detail);
        Assert.Equal("1", t.Home().Stats.AppliedText);
    }

    [Fact]
    public void Recent_activity_shows_the_last_five_or_says_nothing_yet()
    {
        var t = Make();
        Assert.Equal((false, true), (t.Home().HasActivity, t.Home().HasNoActivity));
        var now = new DateTime(2026, 11, 20, 12, 0, 0);
        for (var i = 0; i < 7; i++) t.Activity.Add($"Run {i}", "Install AkariOS", i, "wand", now.AddMinutes(-i * 5));
        var home = t.Home(now);
        Assert.Equal(["Run 6", "Run 5", "Run 4", "Run 3", "Run 2"], home.Activity.Select(a => a.Title));
        Assert.Equal(("30 minutes ago · Install AkariOS", "6 changes", ""), (home.Activity[0].Detail, home.Activity[0].CountText, home.Activity[0].Glyph));
        t.Activity.Add("One", "Downloads", 1, "download", now);
        Assert.Equal(("1 change", ""), (t.Home(now).Activity[0].CountText, t.Home(now).Activity[0].Glyph));
    }

    [Theory]
    [InlineData(0, "Just now")]
    [InlineData(1, "1 minute ago")]
    [InlineData(59, "59 minutes ago")]
    [InlineData(60 * 3, "Today 09:00")]
    [InlineData(60 * 15, "Yesterday")]
    [InlineData(60 * 24 * 3, "17 Nov 2026")]
    public void When_text(int minutesAgo, string text)
    {
        var now = new DateTime(2026, 11, 20, 12, 0, 0);
        Assert.Equal(text, ActivityLog.WhenText(now.AddMinutes(-minutesAgo), now));
    }

    [Fact]
    public void Activity_is_kept_to_twenty_newest_first_in_the_powershell_apps_shape()
    {
        var t = Make();
        for (var i = 0; i < 25; i++) t.Activity.Add($"Run {i}", "Optimize", 1, "x");
        var all = t.Activity.All();
        Assert.Equal((ActivityLog.Max, "Run 24"), (all.Count, all[0].Title));
        var json = File.ReadAllText(Path.Combine(_h.Dir, "activity.json"));
        foreach (var k in new[] { "\"Title\"", "\"Where\"", "\"Count\"", "\"Icon\"", "\"When\"" }) Assert.Contains(k, json);
    }

    [Fact]
    public async Task The_launch_check_on_home_asks_and_updates()
    {
        var t = Make();
        t.Shell.Page = "Home";
        t.Dialogs.Answers.Enqueue("Update now");
        t.Updates.Check(manual: false);
        await Task.Yield();
        Assert.Equal(UpdateKind.Available, t.Updates.Status!.Kind);
        Assert.StartsWith("AkariOS 1.4.0 is available", t.Dialogs.Asked[0]);
        Assert.Contains("What's new:", t.Dialogs.Asked[0]);
        Assert.Contains("Faster", t.Dialogs.Asked[0]);
        // downloaded, swapped in, the new exe started, the app closed
        Assert.Equal(FakeGitHubExe(), File.ReadAllBytes(Path.Combine(_h.Dir, "AkariOS-Native.exe")));
        Assert.Single(t.Started);
        Assert.Equal(["closed"], t.Closed);
    }

    private static byte[] FakeGitHubExe() => AppHarness.FakeGitHub.NewExe;

    [Fact]
    public void Later_keeps_the_infobar_on_home_until_it_is_closed()
    {
        var t = Make();
        t.Shell.Page = "Home";
        var home = t.Home();
        t.Updates.Check(manual: false);
        Assert.Equal((true, "AkariOS 1.4.0 is available", true), (home.UpdateBarOpen, t.Updates.FoundTitle, t.Updates.CanInstall));
        Assert.Empty(t.Closed);
        home.DismissUpdateCommand.Execute(null);
        Assert.False(home.UpdateBarOpen);
        Assert.False(t.Home().UpdateBarOpen);
    }

    [Fact]
    public void Off_home_or_by_hand_the_check_doesnt_ask_and_errors_say_why()
    {
        var t = Make();
        t.Shell.Page = "Settings";
        t.Updates.Check(manual: false);
        Assert.Empty(t.Dialogs.Asked);
        t.GitHub.Status = 0;
        t.Updates.Check(manual: true);
        Assert.Equal((UpdateKind.Error, "Couldn't reach GitHub. Check the internet connection."), (t.Updates.Status!.Kind, t.Updates.StatusText));
        Assert.False(t.Updates.Found);
    }

    [Fact]
    public void A_change_running_blocks_the_update()
    {
        var t = Make();
        t.Dialogs.Answers.Enqueue("Later");
        t.Card("fix-safe").IsOn = true;
        t.Updates.Check(manual: true);
        Assert.Equal(UpdateKind.Blocked, t.Updates.Status!.Kind);
        Assert.True(t.Home().UpdateBarOpen);
        Assert.Equal(t.Updates.Status.Message, t.Home().UpdateBarText);
        Assert.False(t.Updates.CanInstall);
    }

    // ---- Settings

    [Fact]
    public void Settings_sets_the_theme_and_the_accent()
    {
        var t = Make();
        var (theme, settings) = (new Theme(), new Settings());
        var s = t.Settings(theme, settings);
        s.SelectedTheme = AppTheme.Dark;
        Assert.Equal(AppTheme.Dark, theme.CurrentTheme);
        Assert.Equal(["Akari crimson", "Windows accent"], s.Accents.Select(a => a.Label));
        Assert.Equal("Akari crimson", (s.SelectedAccent as ChoiceItem)?.Label);
        s.SelectedAccent = s.Accents[1];
        Assert.Equal((Accent.Windows, (object?)Accent.Windows), (t.Accents.Single(), settings.Values[Accent.Key]));
    }

    [Fact]
    public void Settings_opens_system_restore_the_log_folder_and_links()
    {
        var t = Make();
        var s = t.Settings(new Theme(), new Settings());
        s.OpenSystemRestoreCommand.Execute(null);
        s.OpenLogFolderCommand.Execute(null);
        s.OpenLinkCommand.Execute(s.About.Links[0].Url);
        Assert.Equal([Path.Combine(Environment.SystemDirectory, "rstrui.exe"), Core.AkariPaths.UserFolder, "https://github.com/isleap9/AkariOS"], t.Open.Opened);
        Assert.Contains(s.About.Credits, c => c.Name == "FR33THY Ultimate");
        Assert.StartsWith("MIT License", s.About.License);
    }

    [Fact]
    public async Task Export_writes_this_pcs_settings_as_a_preset()
    {
        var t = Make();
        t.Card("fix-plain").IsOn = true;
        var s = t.Settings(new Theme(), new Settings());
        // cancelled: nothing written
        await s.ExportAsync();
        Assert.StartsWith($"AkariOS settings {Environment.MachineName} ", t.Picker.Suggested[0]);
        t.Picker.SavePath = Path.Combine(_h.Dir, "mine.json");
        await s.ExportAsync();
        Assert.Contains("fix-plain", File.ReadAllText(t.Picker.SavePath));
        Assert.Equal($"Exported 1 setting: {t.Picker.SavePath}", t.Toasts[0]);
        Assert.False(t.Shell.IsBusy);
        // its action opens the folder
        t.Shell.Toasts[0].ActCommand.Execute(null);
        Assert.Equal(_h.Dir, t.Open.Opened[^1]);
        Assert.Empty(t.Shell.Toasts);
    }

    [Fact]
    public async Task Support_file_is_saved_where_the_user_picks()
    {
        var t = Make();
        var s = t.Settings(new Theme(), new Settings());
        // cancelled: nothing written
        await s.SaveSupportFileAsync();
        Assert.StartsWith("AkariOS-support-", t.Picker.Suggested[0]);
        Assert.Empty(t.Toasts);
        t.Picker.ZipPath = Path.Combine(_h.Dir, "support.zip");
        await s.SaveSupportFileAsync();
        using (var zip = System.IO.Compression.ZipFile.OpenRead(t.Picker.ZipPath))
        {
            var info = zip.GetEntry("system.txt");
            Assert.NotNull(info);
            using var r = new StreamReader(info.Open());
            Assert.StartsWith($"AkariOS {Core.AkariInfo.Version} (native app)", r.ReadToEnd());
        }
        Assert.Equal($"Support file saved: {t.Picker.ZipPath}", t.Toasts[0]);
        Assert.False(t.Shell.IsBusy);
        t.Shell.Toasts[0].ActCommand.Execute(null);
        Assert.Equal(_h.Dir, t.Open.Opened[^1]);
    }

    [Fact]
    public async Task The_drift_check_finds_settings_windows_changed_back_and_reviews_them_in_guided()
    {
        var t = Make();
        var settings = new Settings();
        var drift = t.Drift(settings);
        var row = Assert.Single(t.Engine.Find("fix-plain")!.Registry!);
        // nothing recorded yet: the launch check does nothing, the manual one says so
        await drift.CheckAsync(manual: false);
        Assert.False(settings.Values.ContainsKey(DriftCheck.BuildKey));
        await drift.CheckAsync(manual: true);
        Assert.Equal("Your setup is as AkariOS left it: AkariOS has not changed any settings on this PC yet.", t.Toasts[0]);

        // applied from Optimize: recorded; then Windows puts it back
        t.Card("fix-plain").IsOn = true;
        Assert.Equal(Core.Tweaks.TweakMode.Apply, t.Engine.Expected!.All()["fix-plain"].Mode);
        t.Engine.Registry.RemoveValue(row.Path, row.Name!);

        // the launch check runs once per Windows build
        await settings.SetAsync(DriftCheck.BuildKey, drift.BuildRevision());
        await drift.CheckAsync(manual: false);
        Assert.Empty(drift.Items);
        await settings.SetAsync(DriftCheck.BuildKey, "older");
        await drift.CheckAsync(manual: false);
        Assert.Equal(["fix-plain"], drift.Items.Select(d => d.Id));
        Assert.Equal(drift.BuildRevision(), settings.Values[DriftCheck.BuildKey]);
        Assert.Equal("1 setting went back: Windows changed them back, most likely with an update.", t.Toasts[0]);

        // Home's InfoBar, dismissible; Review = Guided's Tweaks step with it picked
        var home = t.Home(drift: drift);
        Assert.True(home.DriftBarOpen);
        Assert.Equal("1 AkariOS setting went back to Windows' values", home.DriftTitle);
        home.ReviewDriftCommand.Execute(null);
        Assert.Equal(("Guided", 1), (t.Install.Mode, t.Install.Step));
        Assert.Equal("Install AkariOS", t.Navigated[^1]);
        Assert.Contains("fix-plain", t.Install.Selection.Keys);
        home.DismissDriftCommand.Execute(null);
        Assert.False(home.DriftBarOpen);
    }

    [Fact]
    public async Task Undo_puts_back_the_last_runs_values_after_asking()
    {
        var t = Make();
        var s = t.Settings(new Theme(), new Settings());
        // nothing yet
        await s.UndoAsync();
        Assert.Equal("There is no Run to undo yet. Guided and One-click Runs are kept here, the last 10.", t.Dialogs.Asked[^1]);

        var row = Assert.Single(t.Engine.Find("fix-plain")!.Registry!);
        t.Engine.Registry.SetValue(row.Path, row.Name!, 7, "DWord");
        Core.Runs.PlanItem[] plan = [new("fix-plain", Core.Tweaks.TweakMode.Apply)];
        t.Engine.History!.Record("Guided run", DateTime.Now, plan, t.Engine.Find, () => t.Engine.Runner.Run(plan, t.Engine.Find));
        Assert.Equal(1u, t.Engine.Registry.GetValue(row.Path, row.Name!));

        // asked with what goes back; cancelled = nothing
        await s.UndoAsync();
        Assert.Contains("- 1 setting go back to what it was before the Run", t.Dialogs.Asked[^1]);
        Assert.Equal(1u, t.Engine.Registry.GetValue(row.Path, row.Name!));
        t.Dialogs.Answers.Enqueue("Undo");
        await s.UndoAsync();
        Assert.Equal(7u, t.Engine.Registry.GetValue(row.Path, row.Name!));
        Assert.Equal("Undid Guided run: 1 setting put back. Restart Windows if a change asked for it.", t.Toasts[0]);
        Assert.Contains(t.Activity.All(), a => a.Title == "Undid \"Guided run\"");
        Assert.Null(t.Engine.History.Last());
    }
}
