using AkariOS.App.ViewModels;
using AkariOS.Core.Tests;

namespace AkariOS.App.Tests;

/// <summary>
/// The ISO Builder (src/UI/IsoBuilder.ps1) through its view model: zISO's cards, each slow step a background job on
/// IsoBuild / IsoDownload over the Core tests' recording fakes (IsoShared.cs), the long ones locking the shell, the
/// refusals between an ISO job and the other changes, the closing question.
/// </summary>
public sealed class IsoBuilderTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private static IReadOnlyList<string> Log(AppTest t) => ((Core.MemoryLog)t.Engine.Log).Lines;

    [Fact]
    public void The_wizard_starts_on_the_modes_with_custom_picked()
    {
        var t = _h.Make();
        var iso = t.Iso;
        Assert.Equal(IsoBuilderViewModel.StartStep, iso.Step);
        Assert.Equal(["Start", "Windows image", "Components", "Build settings", "Review", "Create ISO"], iso.Stepper.Select(s => s.Name));
        Assert.Equal(["Current", "", "", "", "", ""], iso.Stepper.Select(s => s.State));
        Assert.Equal(("Start", true, false), (iso.NextText, iso.CanNext, iso.CanBack));
        Assert.Equal(["AkariOS", "Lite", "Minimal", "Custom"], iso.Modes.Select(m => m.Id));
        Assert.Equal(["AkariOS", "Lite", "Minimal", "Custom"], iso.Modes.Where(m => m.Available).Select(m => m.Id));
        Assert.Equal(["Custom"], iso.Modes.Where(m => m.IsSelected).Select(m => m.Id));
        Assert.Equal(["Recommended", "Update-safe", "For test VMs only", "Choose yourself"], iso.Modes.Select(m => m.Tag));
        // Custom starts with the hardware checks skipped, every group editable
        Assert.True(iso.IsCustom);
        Assert.Equal([IsoBuilderViewModel.CustomStartGroup], iso.RemovalGroups.Where(g => g.IsChecked).Select(g => g.Id));
        Assert.All(iso.RemovalGroups, g => Assert.True(g.IsEditable));
        Assert.Equal("No image yet", iso.ImageSummary);
        Assert.Equal(["Store apps", "Optional features", "Windows features", "OS packages (advanced)"], iso.Lists.Select(l => l.Title));
        Assert.All(iso.Lists, l => Assert.False(l.Shown));
        Assert.Equal(["Windows 11 26H2", "Windows 11 25H2", "Windows 11 24H2", "Windows 11 23H2"], iso.UupVersions);
        Assert.Equal(("File", "Local", true, "Admin"), (iso.Source, iso.Answer, iso.SkipOobe, iso.User));
        Assert.False(iso.EditionEnabled);
        iso.OpenUnattend();
        Assert.Equal(["Install USB"], t.Navigated);
    }

    /// <summary>The ISO picked (Browse…) and the side's output folder.</summary>
    private (AppTest T, IsoBuilderViewModel Iso, IsoBuildOracleTests.Side Side, IsoFakes Fakes) Picked(Dictionary<string, object>? c = null, string? akariExe = null, bool fixtures = false)
    {
        var t = fixtures ? _h.Make(AppHarness.Fixtures()) : _h.Make();
        var (side, fakes) = _h.Iso(t, c, akariExe);
        var iso = t.Iso;
        t.Picker.IsoPath = Path.Combine(side.Root, "Win11.iso");
        iso.PickIsoCommand.Execute(null);
        t.Picker.FolderPath = Path.Combine(side.Root, "out");
        iso.PickFolderCommand.Execute(null);
        Assert.Equal(Path.Combine(side.Root, "Win11.iso"), iso.IsoPath);
        Assert.Equal(Path.Combine(side.Root, "out"), iso.OutDir);
        return (t, iso, side, fakes);
    }

    [Fact]
    public async Task Open_ISO_copies_it_in_the_background_locked_and_lists_its_Windows_11_editions()
    {
        var (t, iso, side, fakes) = Picked();
        t.Work.Hold = true;
        await iso.OpenIsoAsync();
        Assert.True(t.Shell.IsBusy);
        Assert.True(t.Shell.Locked);
        Assert.Equal("Copying the ISO and reading its editions", t.Shell.BusyText);
        Assert.Equal("IsoOpen", iso.Job);
        Assert.True(iso.Working);
        t.Work.Release();
        Assert.False(t.Shell.IsBusy);
        Assert.False(t.Shell.Locked);
        Assert.False(iso.Running);
        Assert.Equal(["Windows 11 Home (10.0.26100.1742)", "Windows 11 Pro (10.0.26100.1742)"], iso.Editions);
        Assert.True(iso.EditionEnabled);
        // Pro picked when the ISO has it
        Assert.Equal(1, iso.EditionIndex);
        Assert.Equal("Opened: 2 Windows 11 editions.", iso.OpenNote);
        Assert.Contains("Copying the ISO and reading its editions", Log(t));
        Assert.Contains(@"DiskMount <root>\Win11.iso", fakes.Calls);
        Assert.True(File.Exists(Path.Combine(side.Root, @"out\AkariIso\Media\sources\install.wim")));
    }

    [Fact]
    public async Task Open_ISO_says_what_is_missing_or_why_it_was_refused()
    {
        var (t, iso, side, _) = Picked(IsoBuildOracleTests.Case(c => c["Drive"] = new { Free = 10L << 30, Format = "NTFS" }));
        iso.IsoPath = Path.Combine(side.Root, "missing.iso");
        await iso.OpenIsoAsync();
        Assert.Equal("Pick an ISO file first (or download one above).", iso.OpenNote);
        iso.IsoPath = Path.Combine(side.Root, "Win11.iso");
        iso.OutDir = "";
        await iso.OpenIsoAsync();
        Assert.Equal("Pick a work and output folder.", iso.OpenNote);
        iso.OutDir = Path.Combine(side.Root, "out");
        await iso.OpenIsoAsync();
        Assert.StartsWith("Not opened: ", iso.OpenNote);
        Assert.Contains("25 GB", iso.OpenNote);
        Assert.False(iso.EditionEnabled);
        Assert.False(t.Shell.IsBusy);
        Assert.False(t.Shell.Locked);
    }

    /// <summary>The ISO picked and opened, Windows 11 Pro chosen.</summary>
    private async Task<(AppTest T, IsoBuilderViewModel Iso, IsoBuildOracleTests.Side Side, IsoFakes Fakes)> Opened(Dictionary<string, object>? c = null, string? akariExe = null)
    {
        var o = Picked(c, akariExe);
        await o.Iso.OpenIsoAsync();
        o.Iso.EditionIndex = 1;
        return o;
    }

    [Fact]
    public async Task The_wizard_waits_for_an_image_reads_its_lists_on_components_and_reviews_the_picks()
    {
        var (t, iso, side, _) = Picked();
        iso.PickModeCommand.Execute("Custom");
        Assert.Equal(IsoBuilderViewModel.ImageStep, iso.Step);
        Assert.Equal(("Next", false, "Open an ISO and pick an edition first."), (iso.NextText, iso.CanNext, iso.NextHint));
        Assert.True(iso.CanBack);

        await iso.OpenIsoAsync();
        Assert.Equal("Windows 11 Pro", iso.Edition?.Name);
        Assert.StartsWith("Windows 11 Pro · ", iso.ImageSummary);
        Assert.True(iso.CanNext);

        // Components reads the edition's lists the first time
        await iso.NextAsync();
        Assert.Equal(IsoBuilderViewModel.ComponentsStep, iso.Step);
        Assert.True(iso.List("Apps").Shown);
        Assert.All(iso.List("Apps").Items, i => Assert.True(i.HasIcon));
        iso.SelectRecommended();

        await iso.NextAsync();
        Assert.Equal((IsoBuilderViewModel.SettingsStep, "Review"), (iso.Step, iso.NextText));
        await iso.NextAsync();
        Assert.Equal((IsoBuilderViewModel.ReviewStep, "Build ISO"), (iso.Step, iso.NextText));
        Assert.Equal(["Windows image", "Custom", "Output and workspace", "Installation options", "Build settings"], iso.ReviewCards.Select(c => c.Title));
        Assert.Equal(string.Join("\n", new Core.Iso.IsoBuildSettings { Compression = Core.Iso.IsoCompression.Recovery }.Lines()), iso.ReviewCards[4].Lines);
        Assert.Contains(Path.Combine(side.Root, "out", "Win11-Akari.iso"), iso.ReviewCards[2].Lines);
        Assert.Contains($"Store apps: {iso.List("Apps").Ticked().Length} of 4", iso.ReviewCards[1].Lines);
        Assert.Equal(["Done", "Done", "Done", "Done", "Current", ""], iso.Stepper.Select(s => s.State));

        iso.Back();
        Assert.Equal(IsoBuilderViewModel.SettingsStep, iso.Step);
        Assert.Empty(t.Dialogs.Asked);
    }

    [Fact]
    public async Task Reading_the_image_mounts_the_edition_and_lists_what_can_be_removed()
    {
        var (t, iso, _, fakes) = await Opened(IsoBuildOracleTests.Case(c =>
            c["ImageCapabilities"] = new[] { new { Name = "Browser.InternetExplorer~~~~0.0.11.0", State = "Installed" }, new { Name = "Language.Basic~~~fr-FR~0.0.1.0", State = "NotPresent" } }));
        iso.SelectRecommended();
        Assert.Equal("Read the image's apps first.", iso.ListNote);
        t.Work.Hold = true;
        await iso.ReadImageAsync();
        Assert.Equal("IsoRead", iso.Job);
        Assert.True(t.Shell.Locked);
        t.Work.Release();
        Assert.Contains(@"Mount <root>\out\AkariIso\install.wim 1 <root>\out\AkariIso\Mount", fakes.Calls);
        Assert.Contains("Reading the apps in Windows 11 Pro", Log(t));
        // the framework (VCLibs) left out
        Assert.Equal("Store apps (4)", iso.List("Apps").Heading);
        Assert.True(iso.List("Apps").Shown);
        Assert.Equal(["Microsoft.BingNews", "Microsoft.Copilot", "Microsoft.SecHealthUI", "Microsoft.WindowsCalculator"], iso.List("Apps").Items.Select(i => i.Label));
        // every Store app has an icon (no logo in the fake image: the app box), the other lists none
        Assert.All(iso.List("Apps").Items, i => Assert.True(i.HasIcon));
        Assert.All(iso.List("Features").Items, i => Assert.False(i.HasIcon));
        // each step timed in akari.log
        Assert.Contains(((Core.MemoryLog)t.Engine.Log).FileLines, l => l.StartsWith("ISO Builder: Reading the features and packages: ", StringComparison.Ordinal));
        Assert.Equal("Optional features (1)", iso.List("Capabilities").Heading);
        Assert.Equal("Windows features (3)", iso.List("Features").Heading);
        Assert.Equal("OS packages (advanced) (0)", iso.List("Packages").Heading);
        Assert.Equal("Tick what to remove. Frameworks are left out of the list (apps need them).", iso.ListNote);

        // Win11Debloat's Safe ones not on the keep-list
        iso.SelectRecommended();
        Assert.Equal(["Microsoft.BingNews", "Microsoft.Copilot"], iso.List("Apps").Items.Where(i => i.IsChecked).Select(i => i.Label));
        iso.List("Features").Items.Single(i => i.Label == "Recall").IsChecked = true;
        iso.ClearLists();
        Assert.DoesNotContain(iso.Lists.SelectMany(l => l.Items), i => i.IsChecked);
    }

    [Fact]
    public async Task Reading_needs_an_opened_ISO_and_says_why_a_mount_failed()
    {
        var t = _h.Make();
        _h.Iso(t);
        await t.Iso.ReadImageAsync();
        Assert.Equal("Open the ISO and pick an edition first.", t.Iso.ListNote);

        var (_, iso, _, _) = await Opened(IsoBuildOracleTests.Case(c => c["Fail"] = "Mount"));
        await iso.ReadImageAsync();
        Assert.Equal("Not read: The image could not be mounted.", iso.ListNote);
        Assert.False(iso.List("Apps").Shown);
    }

    [Fact]
    public async Task Build_needs_an_opened_ISO()
    {
        var t = _h.Make();
        _h.Iso(t);
        await t.Iso.BuildAsync();
        Assert.Equal("Open the ISO and pick an edition first (Windows image).", t.Iso.BuildError);
        Assert.True(t.Iso.HasBuildError);
        Assert.Empty(t.Dialogs.Asked);
    }

    [Fact]
    public async Task Build_asks_then_builds_locked_with_the_picks_and_progress_and_offers_the_folder()
    {
        var exe = Path.Combine(_h.Dir, "AkariOS-Native.exe");
        Directory.CreateDirectory(_h.Dir);
        File.WriteAllText(exe, "exe");
        var (t, iso, side, fakes) = await Opened(akariExe: exe);
        Assert.True(iso.AkariOS);
        await iso.ReadImageAsync();
        iso.SelectRecommended();
        iso.List("Features").Items.Single(i => i.Label == "Recall").IsChecked = true;
        iso.Answer = "None";
        string? during = null;
        fakes.OnOscdimg = () => during = $"{t.Shell.Locked}|{t.Shell.Indeterminate}|{t.Shell.BusyText}";
        t.Dialogs.Answers.Enqueue("Build ISO");
        await iso.BuildAsync();

        Assert.Equal("", iso.BuildError);
        Assert.Equal("Build Win11-Akari.iso from Windows 11 Pro?\n\n1 removal group, 3 apps and features picked from the image. It takes 20 to 40 minutes and AkariOS can't be used meanwhile.",
            t.Dialogs.Asked.Single());
        Assert.NotNull(during);
        Assert.StartsWith("True|False|Building Win11-Akari.iso (", during);
        Assert.Contains(@"Remove Feature <root>\out\AkariIso\Mount Recall", fakes.Calls);
        Assert.Contains(fakes.Shortcuts, l => l.Contains("AkariOS-Native.exe", StringComparison.Ordinal));
        var path = Path.Combine(side.Root, "out", "Win11-Akari.iso");
        Assert.Equal(path, iso.ResultPath);
        Assert.True(iso.HasResult);
        Assert.Equal($"Your ISO is ready: {path}", t.Toasts.Single());
        // the Create ISO step: every stage done, Build another next
        Assert.Equal(IsoBuilderViewModel.BuildStep, iso.Step);
        Assert.NotEmpty(iso.Stages);
        Assert.All(iso.Stages, s => Assert.Equal("Done", s.State));
        // a stage's operations, each ended; the result's size, hash and report
        var recall = iso.Stages.SelectMany(s => s.Operations).Single(o => o.Name == "Windows feature Recall");
        Assert.Equal(Core.Iso.IsoOpState.Done, recall.State);
        Assert.Contains(iso.Stages, s => s.Summary.StartsWith("1 operation", StringComparison.Ordinal));
        Assert.DoesNotContain(iso.Stages.SelectMany(s => s.Operations), o => o.IsRunning);
        Assert.Equal("", iso.CurrentOperation);
        Assert.Contains("SHA-256 ", iso.ResultDetails);
        Assert.Contains(Path.Combine(side.Root, "out", "Win11-Akari.report.json"), iso.ResultDetails);
        Assert.Equal(("Build another", true, false), (iso.NextText, iso.CanNext, iso.CanBack));
        Assert.Empty(iso.Editions);
        Assert.False(iso.EditionEnabled);
        Assert.False(iso.List("Apps").Shown);
        Assert.Equal("The work folder was removed: open the ISO again to build another.", iso.OpenNote);
        Assert.False(t.Shell.IsBusy);
        Assert.False(t.Shell.Locked);
        // the toast's Open folder
        Assert.Equal("Open folder", t.Shell.Toasts[0].ActionText);
        t.Shell.Toasts[0].Act();
        Assert.Equal([Path.Combine(side.Root, "out")], t.Open.Opened);
    }

    [Fact]
    public async Task The_build_settings_start_off_but_recovery_esd_and_go_to_review_the_build_and_its_report()
    {
        var (t, iso, side, fakes) = await Opened();
        Assert.Equal(new Core.Iso.IsoBuildSettings { Compression = Core.Iso.IsoCompression.Recovery }, iso.Settings);
        Assert.Equal(["Recovery ESD (smallest, slowest)", "Maximum WIM", "Fast WIM (largest, quickest)"], IsoBuilderViewModel.CompressionNames);
        Assert.Equal(0, iso.CompressionIndex);

        await iso.ReadImageAsync();
        iso.List("Features").Items.Single(i => i.Label == "Recall").IsChecked = true;
        iso.Answer = "None";
        iso.CompressionIndex = 0;
        iso.Turbo = true;
        iso.CleanLeftovers = true;
        iso.LeaveOutNetFx3Files = true;
        iso.Step = IsoBuilderViewModel.ReviewStep;
        Assert.Equal(
            "Compression: Recovery ESD (smallest, slowest)\nTurbo feature removal: On\nRemove leftover image data: On\n.NET 3.5's setup files on the ISO: Left out",
            iso.ReviewCards.Single(c => c.Title == "Build settings").Lines);

        t.Dialogs.Answers.Enqueue("Build ISO");
        await iso.BuildAsync();
        Assert.True(iso.HasResult);
        Assert.Contains(fakes.Calls, c => c.StartsWith("Export ", StringComparison.Ordinal) && c.EndsWith(@"\Media\sources\install.esd recovery", StringComparison.Ordinal));
        Assert.Contains(fakes.Calls, c => c.Contains("/Disable-Feature /FeatureName:Recall /Remove /NoRestart", StringComparison.Ordinal));
        Assert.DoesNotContain(@"Remove Feature <root>\out\AkariIso\Mount Recall", fakes.Calls);
        Assert.Contains(iso.Stages, s => s.Text == "Removing leftover image data");
        Assert.Contains(iso.Stages, s => s.Text == "Leaving .NET Framework 3.5's setup files off the ISO");
        var report = Core.Iso.IsoReport.FromJson(File.ReadAllText(Path.Combine(side.Root, "out", "Win11-Akari.report.json")))!;
        Assert.Equal(iso.Settings, report.Settings);
    }

    // ---- the modes (batch I4)

    [Fact]
    public async Task The_akarios_mode_fixes_its_groups_reads_no_lists_and_bakes_the_preset_with_the_first_sign_in()
    {
        var exe = Path.Combine(_h.Dir, "AkariOS-Native.exe");
        Directory.CreateDirectory(_h.Dir);
        File.WriteAllText(exe, "exe");
        var (t, iso, side, fakes) = Picked(akariExe: exe);
        iso.PickModeCommand.Execute("AkariOS");
        Assert.Equal(("AkariOS", false, true), (iso.Mode, iso.IsCustom, iso.IsAkariOSMode));
        Assert.Equal(["SkipHardwareChecks", "NoSponsoredApps", "StoreAppsAkariOS", "Edge", "OneDrive"],
            iso.RemovalGroups.Where(g => g.IsChecked).Select(g => g.Id));
        Assert.All(iso.RemovalGroups, g => Assert.False(g.IsEditable));
        Assert.Equal("5 removal groups", iso.PlanText);
        Assert.True(iso.AkariOS);
        await iso.OpenIsoAsync();
        iso.EditionIndex = 1;

        // Components: the plan only, the image's lists not read
        await iso.NextAsync();
        Assert.Equal(IsoBuilderViewModel.ComponentsStep, iso.Step);
        Assert.False(iso.List("Apps").Shown);
        await iso.NextAsync();
        await iso.NextAsync();
        var plan = iso.ReviewCards.Single(c => c.Title == "AkariOS").Lines;
        Assert.Contains("- Microsoft Edge", plan);
        Assert.Matches(@"AkariOS settings written into the image: [1-9]", plan);
        Assert.Contains("The rest at the first sign-in: ", plan);

        iso.Answer = "None";
        t.Dialogs.Answers.Enqueue("Build ISO");
        await iso.BuildAsync();
        Assert.True(iso.HasResult, iso.BuildError);
        Assert.Contains("AkariOS: 5 removal groups.", t.Dialogs.Asked.Single());
        var reg = fakes.Parts.Registry;
        Assert.Equal(1u, reg.GetValue(@"HKLM:\AkariIso_SYSTEM\Setup\LabConfig", "BypassTPMCheck"));
        Assert.Equal(Core.Iso.IsoWizard.FirstSignInCommand,
            reg.GetValue(Core.Iso.IsoData.HiveRoot + Core.Iso.IsoWizard.RunOnceKey, Core.Iso.IsoWizard.RunOnceName));
        // the AkariOS pick removed the image's non-keep Store apps; the stage of the bake ran
        Assert.Contains(iso.Stages.SelectMany(s => s.Operations), o => o.Name == "App Microsoft.BingNews");
        Assert.Contains(iso.Stages, s => s.Text == "Writing the AkariOS settings into the image" && s.State == "Done");
        Assert.Contains(iso.Stages.SelectMany(s => s.Operations), o => o.Name.StartsWith("Tweak ", StringComparison.Ordinal));
    }

    [Fact]
    public async Task The_lite_mode_is_tiny11s_set_on_recovery_esd_and_bakes_nothing()
    {
        var (t, iso, _, fakes) = await Opened();
        iso.PickModeCommand.Execute("Lite");
        Assert.False(iso.IsAkariOSMode);
        Assert.Contains("EdgeWebView", iso.RemovalGroups.Where(g => g.IsChecked).Select(g => g.Id));
        Assert.Equal(Core.Iso.IsoCompression.Recovery, iso.Settings.Compression);
        iso.Answer = "None";
        t.Dialogs.Answers.Enqueue("Build ISO");
        await iso.BuildAsync();
        Assert.True(iso.HasResult, iso.BuildError);
        Assert.Contains(@"Remove Feature <root>\out\AkariIso\Mount Recall", fakes.Calls);
        Assert.DoesNotContain(iso.Stages, s => s.Text == "Writing the AkariOS settings into the image");
        Assert.Equal(0u, fakes.Parts.Registry.GetValue(@"HKLM:\AkariIso_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager", "ShippedWithReserves"));
        Assert.Contains(fakes.Calls, c => c.StartsWith("Export ", StringComparison.Ordinal) && c.EndsWith("install.esd recovery", StringComparison.Ordinal));
    }

    [Fact]
    public void Minimal_asks_for_the_agreement_before_it_is_picked()
    {
        var t = _h.Make();
        var iso = t.Iso;
        // refused: Custom stays
        t.Dialogs.Answers.Enqueue("Cancel");
        iso.PickModeCommand.Execute("Minimal");
        Assert.Equal(IsoBuilderViewModel.MinimalAgreement, t.Dialogs.Asked.Single());
        Assert.Equal(("Custom", IsoBuilderViewModel.StartStep), (iso.Mode, iso.Step));
        // agreed: its groups, fixed, Core's among them
        t.Dialogs.Answers.Enqueue("I understand");
        iso.PickModeCommand.Execute("Minimal");
        Assert.Equal(("Minimal", IsoBuilderViewModel.ImageStep), (iso.Mode, iso.Step));
        Assert.Contains("Tiny11Core", iso.RemovalGroups.Where(g => g.IsChecked).Select(g => g.Id));
        Assert.All(iso.RemovalGroups, g => Assert.False(g.IsEditable));
        // picked again: no second question
        iso.PickModeCommand.Execute("Minimal");
        Assert.Equal(2, t.Dialogs.Asked.Count);
    }

    [Fact]
    public async Task Custom_with_no_groups_skips_the_settings_files_and_boot_steps()
    {
        var (t, iso, _, _) = await Opened();
        iso.PickModeCommand.Execute("Custom");
        iso.RemovalGroups.Single(g => g.Id == IsoBuilderViewModel.CustomStartGroup).IsChecked = false;
        Assert.Equal("0 removal groups", iso.PlanText);
        // a mode and back: Custom starts again
        iso.PickModeCommand.Execute("Lite");
        iso.PickModeCommand.Execute("Custom");
        Assert.Equal([IsoBuilderViewModel.CustomStartGroup], iso.RemovalGroups.Where(g => g.IsChecked).Select(g => g.Id));
        iso.RemovalGroups[0].IsChecked = false;
        iso.Answer = "None";
        t.Dialogs.Answers.Enqueue("Build ISO");
        await iso.BuildAsync();
        Assert.True(iso.HasResult, iso.BuildError);
        Assert.DoesNotContain(iso.Stages, s => s.Text.StartsWith("Skipping the Windows 11 requirements", StringComparison.Ordinal));
        Assert.DoesNotContain(iso.Stages, s => s.Text == "Removing files from the image");
    }

    [Theory]
    [InlineData("10.0.26100.1742", 26100)]
    [InlineData("10.0.22631", 22631)]
    [InlineData("", 0)]
    public void Reads_an_editions_build(string version, int build) => Assert.Equal(build, IsoBuilderViewModel.BuildOf(version));

    [Fact]
    public async Task Build_cancelled_at_the_question_builds_nothing()
    {
        var (t, iso, _, fakes) = await Opened();
        await iso.BuildAsync();
        Assert.Single(t.Dialogs.Asked);
        Assert.DoesNotContain(fakes.Calls, c => c.StartsWith("Oscdimg", StringComparison.Ordinal));
        Assert.False(iso.HasResult);
        Assert.False(t.Shell.IsBusy);
    }

    [Fact]
    public async Task A_failed_build_says_why_and_keeps_the_opened_ISO()
    {
        var (t, iso, _, _) = await Opened(IsoBuildOracleTests.Case(c => c["Fail"] = "Oscdimg"));
        t.Dialogs.Answers.Enqueue("Build ISO");
        await iso.BuildAsync();
        Assert.StartsWith("Not built: ", iso.BuildError);
        Assert.False(iso.HasResult);
        Assert.StartsWith("ISO not built: ", t.Toasts.Single());
        // the stage that failed, the rest not run; Back goes to Review
        Assert.Equal(IsoBuilderViewModel.BuildStep, iso.Step);
        Assert.Single(iso.Stages, s => s.State == "Failed");
        Assert.Contains(iso.Stages, s => s.State == "Not run");
        Assert.StartsWith("Report: ", iso.ResultDetails);
        Assert.True(iso.CanBack);
        Assert.Equal(2, iso.Editions.Count);
        Assert.False(t.Shell.Locked);
    }

    /// <summary>Builds with the answer file picked and returns the autounattend.xml the ISO got ("" = none).</summary>
    private static async Task<string> BuiltAnswer(AppTest t, IsoBuilderViewModel iso, IsoBuildOracleTests.Side side, IsoFakes fakes, params string[] answers)
    {
        var xml = "";
        fakes.OnOscdimg = () =>
        {
            var f = Path.Combine(side.Root, @"out\AkariIso\Media\autounattend.xml");
            xml = File.Exists(f) ? File.ReadAllText(f) : "";
        };
        foreach (var a in answers) t.Dialogs.Answers.Enqueue(a);
        await iso.BuildAsync();
        return xml;
    }

    [Fact]
    public async Task A_local_account_answer_file_creates_the_administrator_or_lets_setup_ask()
    {
        var (t, iso, side, fakes) = await Opened();
        iso.User = "Gamer";
        var xml = await BuiltAnswer(t, iso, side, fakes, "Build ISO");
        Assert.Contains("<Name>Gamer</Name>", xml);
        Assert.Contains("it-IT", xml);

        var (t2, iso2, side2, fakes2) = await Opened();
        iso2.SkipOobe = false;
        iso2.User = "Gamer";
        var xml2 = await BuiltAnswer(t2, iso2, side2, fakes2, "Build ISO");
        Assert.DoesNotContain("<Name>Gamer</Name>", xml2);
        Assert.NotEqual("", xml2);
    }

    [Fact]
    public async Task No_answer_file_leaves_it_out_and_the_generators_choices_go_in()
    {
        var (t, iso, side, fakes) = await Opened();
        iso.Answer = "None";
        Assert.Equal("", await BuiltAnswer(t, iso, side, fakes, "Build ISO"));

        // Install USB never opened: its form starts from the defaults and this PC
        var (t2, iso2, side2, fakes2) = await Opened();
        iso2.AnswerGenerator = true;
        Assert.Equal("Generator", iso2.Answer);
        var xml = await BuiltAnswer(t2, iso2, side2, fakes2, "Build ISO");
        var expected = Core.Unattend.UnattendFile.Make(t2.Unattend.Form.Fields());
        Assert.Equal(System.Text.Encoding.ASCII.GetString(expected), xml);
        Assert.Contains("it-IT", xml);
    }

    [Fact]
    public async Task The_generators_disk_wipe_is_asked_first()
    {
        var (t, iso, side, fakes) = await Opened();
        iso.Answer = "Generator";
        t.Unattend.Shown();
        t.Unattend.Form.Bindings.First(b => b.Field == "PEMode").Pick("Generated");
        Assert.True(t.Unattend.Form.Wipes());
        Assert.Equal("", await BuiltAnswer(t, iso, side, fakes));
        Assert.StartsWith("This file wipes a disk", t.Dialogs.Asked.Single());
        Assert.DoesNotContain(fakes.Calls, c => c.StartsWith("Oscdimg", StringComparison.Ordinal));
        Assert.False(iso.HasBuildError);
    }

    // ---- UUP Dump

    /// <summary>The ISO Builder on UUP Dump's answers (listid, listlangs, listeditions), the output folder set.</summary>
    private (AppTest T, IsoBuilderViewModel Iso, IsoDownloadOracleTests.Side Side, DownloadFakes Fakes) Uup(object[] answers, Action<Dictionary<string, object>>? change = null, bool fixtures = false)
    {
        var t = fixtures ? _h.Make(AppHarness.Fixtures()) : _h.Make();
        var c = IsoDownloadOracleTests.Case();
        c["Answers"] = answers;
        change?.Invoke(c);
        var (side, fakes) = _h.Downloads(t, c);
        var iso = t.Iso;
        iso.OutDir = Path.Combine(side.Root, "out");
        iso.IsUup = true;
        return (t, iso, side, fakes);
    }

    private static readonly object[] Lists = [IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions];

    [Fact]
    public void Picking_a_UUP_version_lists_its_languages_and_editions_without_locking()
    {
        var (t, iso, _, fakes) = Uup(Lists);
        Assert.Equal("Uup", iso.Source);
        Assert.Equal(-1, iso.UupVersionIndex);
        t.Work.Hold = true;
        iso.UupVersionIndex = 1;
        Assert.Equal("IsoUupList", iso.Job);
        Assert.True(t.Shell.IsBusy);
        Assert.False(t.Shell.Locked);
        Assert.False(iso.Working);
        t.Work.Release();
        Assert.Equal(["Api listid search=windows 11 26200 amd64&sortByDate=1", $"Api listlangs id={IsoDownloadOracleTests.BuildId}",
            $"Api listeditions id={IsoDownloadOracleTests.BuildId}&lang=en-us"], fakes.Calls);
        Assert.Equal("Windows 11, version 25H2 (26200.6584) amd64. Pick a language and an edition.", iso.UupNote);
        Assert.Equal(["English (United States)", "French", "German"], iso.UupLanguages);
        Assert.Equal("English (United States)", iso.UupLanguage);
        Assert.Contains("Pro N", iso.UupEditions);
        Assert.Equal("Pro", iso.UupEdition);
        Assert.False(t.Shell.IsBusy);
    }

    [Fact]
    public void Another_language_lists_its_editions()
    {
        var (_, iso, _, fakes) = Uup([.. Lists, IsoDownloadOracleTests.ListEditions]);
        iso.UupVersionIndex = 1;
        iso.UupLanguageIndex = 1;
        Assert.Equal("French", iso.UupLanguage);
        Assert.Equal($"Api listeditions id={IsoDownloadOracleTests.BuildId}&lang=fr-fr", fakes.Calls[^1]);
        Assert.Equal(4, fakes.Calls.Count);
        Assert.Equal("Pro", iso.UupEdition);
    }

    [Fact]
    public void A_UUP_Dump_that_cant_be_reached_says_so()
    {
        var fail = IsoDownloadOracleTests.Fail("Unable to connect to the remote server");
        var (_, iso, _, _) = Uup([fail, fail, fail]);
        iso.UupVersionIndex = 0;
        Assert.Contains("Unable to connect to the remote server", iso.UupNote);
        Assert.Empty(iso.UupLanguages);
    }

    [Fact]
    public async Task Download_needs_the_picks_asks_then_the_ISO_becomes_the_file_to_open()
    {
        var (t, iso, side, _) = Uup(Lists);
        await iso.UupDownloadAsync();
        Assert.Equal("Pick a version, a language and an edition first.", iso.UupNote);
        iso.UupVersionIndex = 1;
        await iso.UupDownloadAsync();
        Assert.Equal("Download Windows 11 25H2 Pro (English (United States)) with UUP Dump?\n\nIt downloads several GB from Microsoft and builds the ISO: allow 20 to 60 minutes. AkariOS can't be used meanwhile.",
            t.Dialogs.Asked.Single());
        Assert.Equal("", iso.IsoPath);

        t.Dialogs.Answers.Enqueue("Download");
        t.Work.Hold = true;
        await iso.UupDownloadAsync();
        var during = $"{iso.Job}|{t.Shell.Locked}";
        t.Work.Release();
        Assert.Equal("IsoUup|True", during);
        var path = Path.Combine(side.Root, "out", "Windows11_25H2_Pro_en-us.iso");
        Assert.Equal(path, iso.IsoPath);
        Assert.Equal("File", iso.Source);
        Assert.True(iso.IsFile);
        Assert.Equal($"Downloaded: {path}. Press Open ISO.", iso.OpenNote);
        Assert.Equal($"Windows 11 downloaded: {path}", t.Toasts.Single());
        Assert.Contains("Done", Log(t));
        Assert.False(t.Shell.Locked);
    }

    [Fact]
    public async Task A_UUP_download_needs_the_folder_and_says_why_it_failed()
    {
        var (t, iso, _, _) = Uup(Lists);
        iso.UupVersionIndex = 1;
        iso.OutDir = "";
        await iso.UupDownloadAsync();
        Assert.Equal("Pick a work and output folder below first.", iso.UupNote);
        Assert.Empty(t.Dialogs.Asked);

        // the converter made no ISO
        var (t2, iso2, _, _) = Uup(Lists, c => c["Script"] = new { Code = 1, Iso = "", Lines = new[] { "Error: aria2 could not download" } });
        iso2.UupVersionIndex = 1;
        t2.Dialogs.Answers.Enqueue("Download");
        await iso2.UupDownloadAsync();
        Assert.StartsWith("Not downloaded: ", iso2.UupNote);
        Assert.Equal("", iso2.IsoPath);
        Assert.Equal("Uup", iso2.Source);
        Assert.StartsWith("Not downloaded: ", t2.Toasts.Single());
    }

    // ---- Massgrave

    [Fact]
    public void Massgrave_lists_its_ISOs_opens_the_page_and_watches_Downloads()
    {
        var t = _h.Make();
        var c = IsoDownloadOracleTests.Case();
        const string file = "en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd.iso";
        c["Pages"] = new Dictionary<string, string?>
        {
            [Core.Iso.Massgrave.Pages[0]] = IsoDownloadOracleTests.Page("Windows 11 Consumer 25H2", "en-us_windows_11_consumer_editions_version_25h2_x64_dvd.iso"),
            [Core.Iso.Massgrave.Pages[1]] = IsoDownloadOracleTests.Page("Windows 11 IoT Enterprise LTSC 2024", file),
        };
        var (side, fakes) = _h.Downloads(t, c);
        var iso = t.Iso;
        iso.IsMassgrave = true;
        Assert.Equal(["Windows 11 Consumer 25H2", "Windows 11 IoT Enterprise LTSC 2024"], iso.MassgraveProducts);
        Assert.StartsWith("Pick an ISO and open its page.", iso.MassgraveNote);
        Assert.False(t.Shell.IsBusy);
        iso.MassgraveProductIndex = 1;
        Assert.Equal(["English"], iso.MassgraveFiles);

        iso.OpenMassgravePage();
        Assert.Equal([$"https://drive.massgrave.dev/{file}"], t.Open.Opened);
        Assert.Equal($"Waiting for {file} in Downloads… (download it in the browser that just opened)", iso.MassgraveNote);
        var timer = t.Timers.All.Single();
        Assert.Equal(TimeSpan.FromSeconds(3), timer.Interval);
        t.Timers.Tick();
        Assert.False(timer.Stopped);
        Assert.Equal("Massgrave", iso.Source);

        // the browser saved it (a second copy, as browsers name them)
        var saved = Path.Combine(side.Root, "downloads", "en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd (1).iso");
        File.WriteAllText(saved, "iso");
        t.Timers.Tick();
        Assert.True(timer.Stopped);
        Assert.Equal(saved, iso.IsoPath);
        Assert.Equal("File", iso.Source);
        Assert.Equal($"Downloaded: {saved}. Press Open ISO.", iso.OpenNote);

        // picked again: the list isn't read twice
        var pages = fakes.Calls.Count;
        iso.IsMassgrave = true;
        Assert.Equal(2, iso.MassgraveProducts.Count);
        Assert.Equal(pages, fakes.Calls.Count);
    }

    // ---- Microsoft (batch I5)

    private (AppTest T, IsoBuilderViewModel Iso, string Downloads, DownloadFakes Fakes) Microsoft(string? page)
    {
        var t = _h.Make();
        var c = IsoDownloadOracleTests.Case();
        c["Pages"] = new Dictionary<string, string?> { [Core.Iso.MicrosoftIso.Page] = page };
        var (side, fakes) = _h.Downloads(t, c);
        var iso = t.Iso;
        iso.IsMicrosoft = true;
        return (t, iso, Path.Combine(side.Root, "downloads"), fakes);
    }

    private static string Sha(string text) =>
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(text)));

    [Fact]
    public void Microsoft_opens_its_page_finds_the_download_and_checks_it_against_microsofts_sha256()
    {
        var (t, iso, downloads, fakes) = Microsoft($"<table><tr><td>English International 64-bit</td><td>{Sha("iso")}</td></tr></table>");
        // the hash list read once, when the source is picked
        Assert.Equal([$"Page {Core.Iso.MicrosoftIso.Page}"], fakes.Calls);
        Assert.Equal(IsoBuilderViewModel.MicrosoftHint, iso.MicrosoftNote);

        iso.OpenMicrosoftPageCommand.Execute(null);
        Assert.Equal([Core.Iso.MicrosoftIso.Page], t.Open.Opened);
        Assert.StartsWith("Waiting for the Windows 11 ISO in Downloads", iso.MicrosoftNote);
        var timer = t.Timers.All.Single();
        // a partial download and another ISO don't count
        File.WriteAllText(Path.Combine(downloads, "Win11_25H2_EnglishInternational_x64.iso.crdownload"), "part");
        File.WriteAllText(Path.Combine(downloads, "other.iso"), "iso");
        t.Timers.Tick();
        Assert.False(timer.Stopped);

        var file = Path.Combine(downloads, "Win11_25H2_EnglishInternational_x64.iso");
        File.WriteAllText(file, "iso");
        t.Timers.Tick();
        Assert.True(timer.Stopped);
        Assert.Equal(file, iso.IsoPath);
        Assert.Equal("File", iso.Source);
        Assert.Equal($"Downloaded and checked against Microsoft's SHA-256 (English International 64-bit): {file}. Press Open ISO.", iso.OpenNote);
        Assert.Equal($"ISO found and checked: {file}", t.Toasts.Single());
        // picked again: the list isn't read twice
        iso.IsMicrosoft = true;
        Assert.Single(fakes.Calls);
    }

    [Fact]
    public void Microsoft_leaves_a_download_that_matches_none_of_its_hashes_unused()
    {
        var (t, iso, downloads, _) = Microsoft($"<table><tr><td>English 64-bit</td><td>{new string('A', 64)}</td></tr></table>");
        iso.OpenMicrosoftPageCommand.Execute(null);
        File.WriteAllText(Path.Combine(downloads, "Win11_25H2_English_x64.iso"), "tampered");
        t.Timers.Tick();
        Assert.Equal("", iso.IsoPath);
        Assert.Equal("Microsoft", iso.Source);
        Assert.StartsWith("Win11_25H2_English_x64.iso doesn't match any SHA-256 value Microsoft publishes", iso.MicrosoftNote);
        Assert.Equal("ISO not used: Its SHA-256 doesn't match Microsoft's.", t.Toasts.Single());
        Assert.Contains(((Core.MemoryLog)t.Engine.Log).FileLines, l => l.Contains("matches no SHA-256 on Microsoft's page", StringComparison.Ordinal));
    }

    [Fact]
    public void Microsoft_uses_the_download_unchecked_when_its_list_cant_be_read_and_says_so()
    {
        var (t, iso, downloads, _) = Microsoft(null);
        Assert.Contains(((Core.MemoryLog)t.Engine.Log).FileLines, l => l.Contains("Couldn't read Microsoft's SHA-256 list", StringComparison.Ordinal));
        iso.OpenMicrosoftPageCommand.Execute(null);
        var file = Path.Combine(downloads, "Win11_25H2_English_x64.iso");
        File.WriteAllText(file, "iso");
        t.Timers.Tick();
        Assert.Equal(file, iso.IsoPath);
        Assert.Equal($"Downloaded: {file} (not checked: Couldn't read Microsoft's SHA-256 list: 404 Not Found). Press Open ISO.", iso.OpenNote);
    }

    [Fact]
    public void Massgrave_out_of_reach_says_so()
    {
        var t = _h.Make();
        _h.Downloads(t, IsoDownloadOracleTests.Case());
        var iso = t.Iso;
        iso.IsMassgrave = true;
        Assert.NotEqual(IsoBuilderViewModel.MassgraveHint, iso.MassgraveNote);
        Assert.DoesNotContain("Pick an ISO", iso.MassgraveNote);
        Assert.Empty(iso.MassgraveProducts);
    }

    // ---- the other changes, closing

    [Fact]
    public async Task Optimize_changes_wait_for_a_long_job_and_a_Guided_Run_or_a_restart_is_refused()
    {
        var (t, iso, _, _) = Picked(fixtures: true);
        t.Work.Hold = true;
        await iso.OpenIsoAsync();
        Assert.True(t.Shell.Locked);

        // Optimize: queued, runs when the ISO is open
        await t.Catalogue.ChangeAsync(t.Engine.Find("fix-plain")!, Core.Tweaks.TweakMode.Apply);
        Assert.Null(t.Fix("Plain"));
        Assert.Equal(1, t.Catalogue.Queued);

        // Install AkariOS and the PC's restart: refused, saying what runs
        t.Install.Selection["fix-plain"] = new Core.Tweaks.Pending("fix-plain", "Plain", Core.Tweaks.TweakMode.Apply, null, false, "Default", "Optimized");
        await t.Install.ApplyAsync();
        Assert.Equal("Copying the ISO and reading its editions is still running. Apply these when it is done.", t.Dialogs.Asked[^1]);
        Assert.False(t.Install.Running);
        await t.Catalogue.RestartPcAsync();
        Assert.Equal("Copying the ISO and reading its editions is still running. Restart when it is done.", t.Dialogs.Asked[^1]);
        Assert.Equal(0, t.Shutdown.Restarts);

        // the update can't be installed meanwhile: Blocked by the busy shell
        Assert.True(t.Shell.IsBusy);

        t.Work.Release();
        Assert.False(iso.Running);
        Assert.Equal(1u, t.Fix("Plain"));
    }

    [Fact]
    public async Task A_long_ISO_job_is_refused_while_an_Optimize_change_runs_a_website_question_is_not()
    {
        var (t, iso, _, fakes) = Picked(fixtures: true);
        t.Work.Hold = true;
        await t.Catalogue.ChangeAsync(t.Engine.Find("fix-plain")!, Core.Tweaks.TweakMode.Apply);
        Assert.True(t.Catalogue.Running);
        await iso.OpenIsoAsync();
        Assert.Equal(["Wait until the changes running now are done, then try again."], t.Dialogs.Asked);
        Assert.Null(iso.Job);
        t.Work.Release();
        Assert.DoesNotContain(fakes.Calls, c => c.StartsWith("DiskMount", StringComparison.Ordinal));

        // UUP Dump's lists only ask a website: they run beside an Optimize change
        var (t2, iso2, _, dl) = Uup(Lists, fixtures: true);
        t2.Work.Hold = true;
        await t2.Catalogue.ChangeAsync(t2.Engine.Find("fix-plain")!, Core.Tweaks.TweakMode.Apply);
        iso2.UupVersionIndex = 1;
        Assert.Equal("IsoUupList", iso2.Job);
        Assert.Empty(t2.Dialogs.Asked);
        t2.Work.Release();
        Assert.Equal(3, dl.Calls.Count);
    }

    [Fact]
    public async Task One_ISO_job_at_a_time()
    {
        var (t, iso, _, _) = Picked();
        t.Work.Hold = true;
        await iso.OpenIsoAsync();
        await iso.OpenIsoAsync();
        Assert.Equal("The ISO Builder is still working (Copying the ISO and reading its editions). Try again when it is done.", t.Dialogs.Asked.Single());
        Assert.Single(t.Work.Held);
        t.Work.Release();
    }

    [Fact]
    public async Task Closing_names_the_job_running()
    {
        var (t, iso, _, _) = Picked();
        Assert.False(t.Closing.MustAsk);
        t.Work.Hold = true;
        await iso.OpenIsoAsync();
        Assert.True(t.Closing.MustAsk);
        Assert.Equal(["Copying the ISO and reading its editions"], t.Closing.Running());
        t.Work.Release();
        Assert.False(t.Closing.MustAsk);
    }

    [Fact]
    public async Task A_developer_build_leaves_AkariOS_out_saying_why()
    {
        var (t, iso, _, fakes) = await Opened();
        Assert.False(iso.AkariOS);
        Assert.False(iso.AkariOSEnabled);
        Assert.Contains("developer build", iso.AkariOSNote);
        t.Dialogs.Answers.Enqueue("Build ISO");
        await iso.BuildAsync();
        Assert.Empty(fakes.Shortcuts);
        Assert.True(iso.HasResult);
    }
}
