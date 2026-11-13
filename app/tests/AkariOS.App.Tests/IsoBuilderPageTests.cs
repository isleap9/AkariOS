using System.IO;
using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Pages;
using AkariOS.Core.Tests;
using static AkariOS.App.Tests.AppHarness;

namespace AkariOS.App.Tests;

/// <summary>
/// The ISO Builder page (src/UI/IsoBuilder.ps1), through AppHarness: zISO's cards, each slow step a background job
/// on IsoBuild / IsoDownload over the recording fakes of the Core tests (IsoShared.cs), the refusals between an ISO
/// job and the other changes, the question on closing.
/// </summary>
[Collection("Motion")]
public sealed class IsoBuilderPageTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    /// <summary>The tile: the page opened and built (no window here: PageFactory builds it as the window would).</summary>
    private static (IsoPage Page, FrameworkElement View) Show(AppTest t)
    {
        t.S.Shell.Open("ISO Builder");
        var view = (FrameworkElement)PageFactory.For(t.S)("ISO Builder");
        return (t.S.Iso!, view);
    }

    [Fact]
    public void The_tile_opens_zISOs_cards_full_page_built_once_and_Back_goes_Home() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        var (_, view) = Show(t);
        var texts = Texts(view);
        string[] cards = ["1  Windows 11 ISO", "2  Edition", "3  Answer file", "4  Windows Update", "5  Security and privacy", "6  Apps", "7  AkariOS", "Build"];
        Assert.Equal(cards, texts.Where(cards.Contains));
        Assert.Contains("Disable all Windows updates", All<CheckBox>(view).Select(c => c.Content as string));
        Assert.DoesNotContain("Not in the native app yet", texts);
        Assert.Same(view, PageFactory.For(t.S)("ISO Builder"));
        Click(All<Button>(view).Single(b => b.Content as string == "Back"));
        Assert.Equal("Home", t.S.Shell.Page);
    });

    private static Button ButtonOf(FrameworkElement view, string text) => All<Button>(view).Single(b => b.Content as string == text);

    /// <summary>The page with an ISO picked (Browse…) and the side's output folder.</summary>
    private (AppTest T, IsoPage Page, FrameworkElement View, IsoBuildOracleTests.Side Side, IsoFakes Fakes) Picked(Dictionary<string, object>? c = null, Action<AppTest>? before = null)
    {
        var t = _h.Make();
        before?.Invoke(t);
        var (side, fakes) = _h.Iso(t, c);
        var (page, view) = Show(t);
        t.Picker.IsoPath = Path.Combine(side.Root, "Win11.iso");
        var (browseIso, browseFolder) = (All<Button>(view).First(b => b.Content as string == "Browse…"), All<Button>(view).Last(b => b.Content as string == "Browse…"));
        Click(browseIso);
        t.Picker.FolderPath = Path.Combine(side.Root, "out");
        Click(browseFolder);
        Assert.Equal(Path.Combine(side.Root, "out"), page.OutDir);
        return (t, page, view, side, fakes);
    }

    [Fact]
    public void Open_ISO_copies_it_in_the_background_and_lists_its_Windows_11_editions() => LookTests.OnSta(() =>
    {
        var (t, page, view, side, fakes) = Picked();
        Assert.False(page.EditionEnabled);
        t.Work.Hold = true;
        Click(ButtonOf(view, "Open ISO"));
        Assert.True(t.S.Shell.Busy);
        Assert.True(t.S.Shell.Locked);
        Assert.True(page.Running);
        Assert.Equal("IsoOpen", page.Job);
        t.Work.Release();
        Assert.False(t.S.Shell.Busy);
        Assert.False(page.Running);
        Assert.Equal(["Windows 11 Home (10.0.26100.1742)", "Windows 11 Pro (10.0.26100.1742)"], page.EditionNames);
        Assert.True(page.EditionEnabled);
        Assert.Equal("Opened: 2 Windows 11 editions.", page.OpenNote);
        Assert.Contains("Copying the ISO and reading its editions", ((Core.MemoryLog)t.S.Log).Lines);
        Assert.Contains(@"DiskMount <root>\Win11.iso", fakes.Calls);
        Assert.True(File.Exists(Path.Combine(side.Root, @"out\AkariIso\Media\sources\install.wim")));
    });

    [Fact]
    public void Open_ISO_says_what_is_missing_or_why_it_was_refused() => LookTests.OnSta(() =>
    {
        var (t, page, view, side, _) = Picked(IsoBuildOracleTests.Case(c => c["Drive"] = new { Free = 10L << 30, Format = "NTFS" }));
        page.IsoPath = Path.Combine(side.Root, "missing.iso");
        Click(ButtonOf(view, "Open ISO"));
        Assert.Equal("Pick an ISO file first (or download one above).", page.OpenNote);
        page.IsoPath = Path.Combine(side.Root, "Win11.iso");
        page.OutDir = "";
        Click(ButtonOf(view, "Open ISO"));
        Assert.Equal("Pick a work and output folder.", page.OpenNote);
        page.OutDir = Path.Combine(side.Root, "out");
        Click(ButtonOf(view, "Open ISO"));
        Assert.StartsWith("Not opened: ", page.OpenNote);
        Assert.Contains("25 GB", page.OpenNote);
        Assert.False(page.EditionEnabled);
        Assert.False(t.S.Shell.Busy);
    });

    /// <summary>The ISO picked and opened, Windows 11 Pro chosen.</summary>
    private (AppTest T, IsoPage Page, FrameworkElement View, IsoBuildOracleTests.Side Side, IsoFakes Fakes) Opened(Dictionary<string, object>? c = null, Action<AppTest>? before = null)
    {
        var o = Picked(c, before);
        Click(ButtonOf(o.View, "Open ISO"));
        o.Page.EditionIndex = 1;
        return o;
    }

    [Fact]
    public void Reading_the_image_mounts_the_edition_and_lists_what_can_be_removed() => LookTests.OnSta(() =>
    {
        var (t, page, view, _, fakes) = Opened(IsoBuildOracleTests.Case(c =>
            c["ImageCapabilities"] = new[] { new { Name = "Browser.InternetExplorer~~~~0.0.11.0", State = "Installed" }, new { Name = "Language.Basic~~~fr-FR~0.0.1.0", State = "NotPresent" } }));
        Assert.Equal("", page.ListHeading("Apps"));
        Click(ButtonOf(view, "Select recommended"));
        Assert.Equal("Read the image's apps first.", page.ListNote);
        t.Work.Hold = true;
        Click(ButtonOf(view, "Read the image's apps"));
        Assert.Equal("IsoRead", page.Job);
        Assert.True(t.S.Shell.Locked);
        t.Work.Release();
        Assert.Contains(@"Mount <root>\out\AkariIso\install.wim 1 <root>\out\AkariIso\Mount", fakes.Calls);
        Assert.Contains("Reading the apps in Windows 11 Pro", ((Core.MemoryLog)t.S.Log).Lines);
        // the framework (VCLibs) left out, by name
        Assert.Equal("Store apps (4)", page.ListHeading("Apps"));
        Assert.Equal(["Microsoft.BingNews", "Microsoft.Copilot", "Microsoft.SecHealthUI", "Microsoft.WindowsCalculator"], page.ListItems("Apps").Select(i => i.Label));
        Assert.Equal("Optional features (1)", page.ListHeading("Capabilities"));
        Assert.Equal("Windows features (3)", page.ListHeading("Features"));
        Assert.Equal("OS packages (advanced) (0)", page.ListHeading("Packages"));
        Assert.Equal("Tick what to remove. Frameworks are left out of the list (apps need them).", page.ListNote);

        // Win11Debloat's Safe ones not on the keep-list
        Click(ButtonOf(view, "Select recommended"));
        Assert.Equal(["Microsoft.BingNews", "Microsoft.Copilot"], page.ListItems("Apps").Where(i => i.Ticked).Select(i => i.Label));
        page.Tick("Features", "Recall");
        Click(ButtonOf(view, "Clear"));
        Assert.DoesNotContain(page.ListItems("Apps").Concat(page.ListItems("Features")), i => i.Ticked);
    });

    [Fact]
    public void Reading_needs_an_opened_ISO_and_says_why_a_mount_failed() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        _h.Iso(t);
        var (page, view) = Show(t);
        Click(ButtonOf(view, "Read the image's apps"));
        Assert.Equal("Open the ISO and pick an edition first.", page.ListNote);

        var (_, page2, view2, _, _) = Opened(IsoBuildOracleTests.Case(c => c["Fail"] = "Mount"));
        Click(ButtonOf(view2, "Read the image's apps"));
        Assert.Equal("Not read: The image could not be mounted.", page2.ListNote);
        Assert.Equal("", page2.ListHeading("Apps"));
    });

    [Fact]
    public void An_option_greys_out_the_ones_it_rules_out() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        var (page, _) = Show(t);
        page.SetOption("SecurityOnly", true);
        page.SetOption("DisableUpdates", true);
        Assert.False(page.Option("SecurityOnly"));
        Assert.False(page.OptionEnabled("SecurityOnly"));
        page.SetOption("DisableUpdates", false);
        Assert.True(page.OptionEnabled("SecurityOnly"));
    });

    [Fact]
    public void Build_needs_an_opened_ISO() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        _h.Iso(t);
        var (page, view) = Show(t);
        Click(ButtonOf(view, "Build ISO"));
        Assert.Equal("Open the ISO and pick an edition first (step 1 and 2).", page.BuildError);
        Assert.Empty(t.Asked);
    });

    [Fact]
    public void Build_asks_then_builds_with_the_picks_and_progress_and_offers_the_folder() => LookTests.OnSta(() =>
    {
        var exe = Path.Combine(_h.Dir, "AkariOS-Native.exe");
        Directory.CreateDirectory(_h.Dir);
        File.WriteAllText(exe, "exe");
        var (t, page, view, side, fakes) = Opened(before: t => t.S.AkariExe = exe);
        Assert.True(page.AkariOS);
        Click(ButtonOf(view, "Read the image's apps"));
        Click(ButtonOf(view, "Select recommended"));
        page.Tick("Features", "Recall");
        page.SetOption("DisableTelemetry", true);
        page.Answer = "None";
        string? during = null;
        fakes.OnOscdimg = () => during = $"{t.S.Shell.Locked}|{t.S.Shell.Progress:0.00}|{t.S.Shell.StatusText}";
        t.Answers.Enqueue("Build ISO");
        Click(ButtonOf(view, "Build ISO"));

        Assert.Equal("", page.BuildError);
        Assert.Equal("Build Win11-Akari.iso from Windows 11 Pro?\n\n1 options, 3 apps and features to remove. It takes 20 to 40 minutes and AkariOS can't be used meanwhile.", t.Asked[0]);
        Assert.NotNull(during);
        Assert.StartsWith("True|", during);
        Assert.Contains("Building Win11-Akari.iso", during);
        Assert.Contains(@"Remove Feature <root>\out\AkariIso\Mount Recall", fakes.Calls);
        Assert.Contains(fakes.Shortcuts, l => l.EndsWith(@"AkariOS-Native.exe|C:\AkariOS", StringComparison.Ordinal) || l.Contains("AkariOS-Native.exe"));
        var iso = Path.Combine(side.Root, "out", "Win11-Akari.iso");
        Assert.Equal($"ISO ready: {iso}", page.BuildResult);
        Assert.Equal("", page.BuildError);
        Assert.Equal($"Your ISO is ready:\n\n{iso}", t.Asked[1]);
        Assert.True(page.OpenFolderShown);
        Assert.Empty(page.EditionNames);
        Assert.False(page.EditionEnabled);
        Assert.Equal("", page.ListHeading("Apps"));
        Assert.Equal("The work folder was removed: open the ISO again to build another.", page.OpenNote);
        Assert.False(t.S.Shell.Busy);
        Click(ButtonOf(view, "Open folder"));
        Assert.Equal([Path.Combine(side.Root, "out")], t.Opened);
    });

    [Fact]
    public void Build_cancelled_at_the_question_builds_nothing() => LookTests.OnSta(() =>
    {
        var (t, page, view, _, fakes) = Opened();
        Click(ButtonOf(view, "Build ISO"));
        Assert.Single(t.Asked);
        Assert.DoesNotContain(fakes.Calls, c => c.StartsWith("Oscdimg", StringComparison.Ordinal));
        Assert.Equal("", page.BuildResult);
        Assert.False(t.S.Shell.Busy);
    });

    [Fact]
    public void A_failed_build_says_why() => LookTests.OnSta(() =>
    {
        var (t, page, view, _, _) = Opened(IsoBuildOracleTests.Case(c => c["Fail"] = "Oscdimg"));
        t.Answers.Enqueue("Build ISO");
        Click(ButtonOf(view, "Build ISO"));
        Assert.StartsWith("Not built: ", page.BuildError);
        Assert.Equal("", page.BuildResult);
        Assert.False(page.OpenFolderShown);
        Assert.Equal(2, page.EditionNames.Count);
    });

    /// <summary>Builds with the answer file picked and returns the autounattend.xml the ISO got ("" = none).</summary>
    private static string BuiltAnswer(AppTest t, FrameworkElement view, IsoBuildOracleTests.Side side, IsoFakes fakes, params string[] answers)
    {
        var xml = "";
        fakes.OnOscdimg = () =>
        {
            var f = Path.Combine(side.Root, @"out\AkariIso\Media\autounattend.xml");
            xml = File.Exists(f) ? File.ReadAllText(f) : "";
        };
        foreach (var a in answers) t.Answers.Enqueue(a);
        Click(ButtonOf(view, "Build ISO"));
        return xml;
    }

    [Fact]
    public void A_local_account_answer_file_creates_the_administrator_or_lets_setup_ask() => LookTests.OnSta(() =>
    {
        var (t, page, view, side, fakes) = Opened();
        Assert.Equal("Local", page.Answer);
        Assert.True(page.SkipOobe);
        Assert.Equal("Admin", page.User);
        page.User = "Gamer";
        var xml = BuiltAnswer(t, view, side, fakes, "Build ISO");
        Assert.Contains("<Name>Gamer</Name>", xml);
        Assert.Contains("it-IT", xml);

        var (t2, page2, view2, side2, fakes2) = Opened();
        page2.SkipOobe = false;
        var xml2 = BuiltAnswer(t2, view2, side2, fakes2, "Build ISO");
        Assert.DoesNotContain("<Name>Gamer</Name>", xml2);
        Assert.NotEqual("", xml2);
    });

    [Fact]
    public void No_answer_file_leaves_it_out_and_the_generators_choices_go_in() => LookTests.OnSta(() =>
    {
        var (t, page, view, side, fakes) = Opened();
        page.Answer = "None";
        Assert.Equal("", BuiltAnswer(t, view, side, fakes, "Build ISO"));

        // the generator's page never opened: its form starts from the defaults and this PC
        var (t2, page2, view2, side2, fakes2) = Opened();
        page2.Answer = "Generator";
        var xml = BuiltAnswer(t2, view2, side2, fakes2, "Build ISO");
        var expected = Core.Unattend.UnattendFile.Make(t2.S.Unattend!.Form.Fields());
        Assert.Equal(System.Text.Encoding.ASCII.GetString(expected), xml);
        Assert.Contains("it-IT", xml);
    });

    [Fact]
    public void The_generators_disk_wipe_is_asked_first() => LookTests.OnSta(() =>
    {
        var (t, page, view, side, fakes) = Opened();
        page.Answer = "Generator";
        PageFactory.For(t.S)("Unattend Generator");
        t.S.Unattend!.Form.Bindings.First(b => b.Field == "PEMode").Pick("Generated");
        Assert.True(t.S.Unattend.Form.Wipes());
        Assert.Equal("", BuiltAnswer(t, view, side, fakes));
        Assert.StartsWith("This file wipes a disk", t.Asked.Single());
        Assert.DoesNotContain(fakes.Calls, c => c.StartsWith("Oscdimg", StringComparison.Ordinal));
    });

    // ---- UUP Dump

    /// <summary>The page on UUP Dump's answers (listid, listlangs, listeditions), the output folder set.</summary>
    private (AppTest T, IsoPage Page, FrameworkElement View, IsoDownloadOracleTests.Side Side, DownloadFakes Fakes) Uup(params object[] answers)
    {
        var t = _h.Make();
        var c = IsoDownloadOracleTests.Case();
        c["Answers"] = answers;
        var (side, fakes) = _h.Downloads(t, c);
        var (page, view) = Show(t);
        page.OutDir = Path.Combine(side.Root, "out");
        page.Source = "Uup";
        return (t, page, view, side, fakes);
    }

    [Fact]
    public void Picking_a_UUP_version_lists_its_languages_and_editions_without_locking() => LookTests.OnSta(() =>
    {
        var (t, page, view, _, fakes) = Uup(IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions);
        Assert.Equal(["Windows 11 26H2", "Windows 11 25H2", "Windows 11 24H2", "Windows 11 23H2"], page.UupVersions);
        Assert.Equal(-1, page.UupVersionIndex);
        t.Work.Hold = true;
        page.UupVersionIndex = 1;
        Assert.Equal("IsoUupList", page.Job);
        Assert.True(t.S.Shell.Busy);
        Assert.False(t.S.Shell.Locked);
        Assert.False(page.Working);
        t.Work.Release();
        Assert.Equal(["Api listid search=windows 11 26200 amd64&sortByDate=1", $"Api listlangs id={IsoDownloadOracleTests.BuildId}",
            $"Api listeditions id={IsoDownloadOracleTests.BuildId}&lang=en-us"], fakes.Calls);
        Assert.Equal("Windows 11, version 25H2 (26200.6584) amd64. Pick a language and an edition.", page.UupNote);
        Assert.Equal(["English (United States)", "French", "German"], page.UupLanguages);
        Assert.Equal("English (United States)", page.UupLanguage);
        Assert.Contains("Pro N", page.UupEditionNames);
        Assert.Equal("Pro", page.UupEdition);
        Assert.False(t.S.Shell.Busy);
    });

    [Fact]
    public void Another_language_lists_its_editions() => LookTests.OnSta(() =>
    {
        var (_, page, _, _, fakes) = Uup(IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions, IsoDownloadOracleTests.ListEditions);
        page.UupVersionIndex = 1;
        page.UupLanguageIndex = 1;
        Assert.Equal("French", page.UupLanguage);
        Assert.Equal($"Api listeditions id={IsoDownloadOracleTests.BuildId}&lang=fr-fr", fakes.Calls[^1]);
        Assert.Equal(4, fakes.Calls.Count);
        Assert.Equal("Pro", page.UupEdition);
    });

    [Fact]
    public void A_UUP_Dump_that_cant_be_reached_says_so() => LookTests.OnSta(() =>
    {
        var fail = IsoDownloadOracleTests.Fail("Unable to connect to the remote server");
        var (_, page, _, _, _) = Uup(fail, fail, fail);
        page.UupVersionIndex = 0;
        Assert.Contains("Unable to connect to the remote server", page.UupNote);
        Assert.Empty(page.UupLanguages);
    });

    [Fact]
    public void Download_needs_the_picks_asks_then_the_ISO_becomes_the_file_to_open() => LookTests.OnSta(() =>
    {
        var (t, page, view, side, _) = Uup(IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions);
        Click(ButtonOf(view, "Download"));
        Assert.Equal("Pick a version, a language and an edition first.", page.UupNote);
        page.UupVersionIndex = 1;
        Click(ButtonOf(view, "Download"));
        Assert.Equal("Download Windows 11 25H2 Pro (English (United States)) with UUP Dump?\n\nIt downloads several GB from Microsoft and builds the ISO: allow 20 to 60 minutes. AkariOS can't be used meanwhile.", t.Asked.Single());
        Assert.Equal("Uup", page.Source);
        Assert.Equal("", page.IsoPath);

        t.Answers.Enqueue("Download");
        string? during = null;
        t.Work.Hold = true;
        Click(ButtonOf(view, "Download"));
        during = $"{page.Job}|{t.S.Shell.Locked}";
        t.Work.Release();
        Assert.Equal("IsoUup|True", during);
        var iso = Path.Combine(side.Root, "out", "Windows11_25H2_Pro_en-us.iso");
        Assert.Equal(iso, page.IsoPath);
        Assert.Equal("File", page.Source);
        Assert.Equal($"Downloaded: {iso}. Press Open ISO.", page.OpenNote);
        Assert.Contains("Done", ((Core.MemoryLog)t.S.Log).Lines);
    });

    [Fact]
    public void A_UUP_download_needs_the_folder_and_says_why_it_failed() => LookTests.OnSta(() =>
    {
        var (t, page, view, _, _) = Uup(IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions);
        page.UupVersionIndex = 1;
        page.OutDir = "";
        Click(ButtonOf(view, "Download"));
        Assert.Equal("Pick a work and output folder below first.", page.UupNote);
        Assert.Empty(t.Asked);

        // the converter made no ISO
        var c = IsoDownloadOracleTests.Case();
        c["Answers"] = new[] { IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions };
        c["Script"] = new { Code = 1, Iso = "", Lines = new[] { "Error: aria2 could not download" } };
        var t2 = _h.Make();
        var (side2, _) = _h.Downloads(t2, c);
        var (page2, view2) = Show(t2);
        page2.OutDir = Path.Combine(side2.Root, "out");
        page2.Source = "Uup";
        page2.UupVersionIndex = 1;
        t2.Answers.Enqueue("Download");
        Click(ButtonOf(view2, "Download"));
        Assert.StartsWith("Not downloaded: ", page2.UupNote);
        Assert.Equal("", page2.IsoPath);
        Assert.Equal("Uup", page2.Source);
    });

    // ---- Massgrave

    [Fact]
    public void Massgrave_lists_its_ISOs_opens_the_page_and_watches_Downloads() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        var c = IsoDownloadOracleTests.Case();
        const string file = "en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd.iso";
        c["Pages"] = new Dictionary<string, string?>
        {
            [Core.Iso.Massgrave.Pages[0]] = IsoDownloadOracleTests.Page("Windows 11 Consumer 25H2", "en-us_windows_11_consumer_editions_version_25h2_x64_dvd.iso"),
            [Core.Iso.Massgrave.Pages[1]] = IsoDownloadOracleTests.Page("Windows 11 IoT Enterprise LTSC 2024", file),
        };
        var (side, _) = _h.Downloads(t, c);
        var (page, view) = Show(t);
        page.Source = "Massgrave";
        Assert.Equal(["Windows 11 Consumer 25H2", "Windows 11 IoT Enterprise LTSC 2024"], page.MassgraveProducts);
        Assert.StartsWith("Pick an ISO and open its page.", page.MassgraveNote);
        page.MassgraveProductIndex = 1;
        Assert.Equal(["English"], page.MassgraveFiles);

        Click(ButtonOf(view, "Open download page"));
        Assert.Equal([$"https://drive.massgrave.dev/{file}"], t.Links);
        Assert.Equal($"Waiting for {file} in Downloads… (download it in the browser that just opened)", page.MassgraveNote);
        var timer = t.Timers.All.Single();
        Assert.Equal(TimeSpan.FromSeconds(3), timer.Interval);
        t.Timers.Tick();
        Assert.False(timer.Stopped);
        Assert.Equal("Massgrave", page.Source);

        // the browser saved it (a second copy, as browsers name them)
        var saved = Path.Combine(side.Root, "downloads", "en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd (1).iso");
        File.WriteAllText(saved, "iso");
        t.Timers.Tick();
        Assert.True(timer.Stopped);
        Assert.Equal(saved, page.IsoPath);
        Assert.Equal("File", page.Source);
        Assert.Equal($"Downloaded: {saved}. Press Open ISO.", page.OpenNote);

        // picked again: the list isn't read twice
        page.Source = "Massgrave";
        Assert.Equal(2, page.MassgraveProducts.Count);
    });

    [Fact]
    public void Massgrave_out_of_reach_says_so() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        _h.Downloads(t, IsoDownloadOracleTests.Case());
        var (page, _) = Show(t);
        page.Source = "Massgrave";
        Assert.NotEqual("", page.MassgraveNote);
        Assert.DoesNotContain("Pick an ISO", page.MassgraveNote);
        Assert.Empty(page.MassgraveProducts);
    });

    // ---- refusals, closing

    /// <summary>Fixture Tweaks, the ISO Builder on UUP Dump's answers, a version picked while background work is held:
    /// the list job still runs.</summary>
    private (AppTest T, IsoPage Page) ListJobRunning()
    {
        var t = _h.Make(Fixtures());
        var c = IsoDownloadOracleTests.Case();
        c["Answers"] = new[] { IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions };
        _h.Downloads(t, c);
        var (page, _) = Show(t);
        page.Source = "Uup";
        t.Work.Hold = true;
        page.UupVersionIndex = 1;
        Assert.True(page.Running);
        return (t, page);
    }

    [Fact]
    public void An_Optimize_change_or_a_Guided_Run_is_refused_while_an_ISO_job_runs() => LookTests.OnSta(() =>
    {
        var (t, page) = ListJobRunning();
        t.Page.Change(t.S.Engine.Find("fix-plain")!, Core.Tweaks.TweakMode.Apply);
        Assert.Equal(["The ISO Builder is still working. Make this change when it is done."], t.Asked);
        Assert.False(t.Page.Running);
        Assert.Equal(1, t.Work.Held);

        t.Install.Selection["fix-plain"] = new Core.Tweaks.Pending("fix-plain", "Plain", Core.Tweaks.TweakMode.Apply, null, false, "Default", "Optimized");
        t.Install.Apply();
        Assert.Equal("The ISO Builder is still working. Apply these when it is done.", t.Asked[^1]);
        Assert.False(t.Install.Running);

        t.Work.Release();
        Assert.False(page.Running);
        t.Page.Change(t.S.Engine.Find("fix-plain")!, Core.Tweaks.TweakMode.Apply);
        Assert.Equal(1u, Fix(t.S, "Plain"));
    });

    [Fact]
    public void An_ISO_job_is_refused_while_an_Optimize_change_runs() => LookTests.OnSta(() =>
    {
        var t = _h.Make(Fixtures());
        var c = IsoDownloadOracleTests.Case();
        c["Answers"] = new[] { IsoDownloadOracleTests.ListId, IsoDownloadOracleTests.ListLangs, IsoDownloadOracleTests.ListEditions };
        var (_, fakes) = _h.Downloads(t, c);
        var (page, _) = Show(t);
        page.Source = "Uup";
        t.Work.Hold = true;
        t.Page.Change(t.S.Engine.Find("fix-plain")!, Core.Tweaks.TweakMode.Apply);
        Assert.True(t.Page.Running);
        page.UupVersionIndex = 1;
        Assert.Equal(["Wait until the changes running now are done, then try again."], t.Asked);
        Assert.Null(page.Job);
        t.Work.Release();
        Assert.Empty(fakes.Calls);
    });

    [Fact]
    public void Closing_asks_first_while_a_long_job_runs() => LookTests.OnSta(() =>
    {
        var (t, page, view, _, _) = Picked();
        Assert.True(page.CanClose());
        t.Work.Hold = true;
        Click(ButtonOf(view, "Open ISO"));
        t.Answers.Enqueue("Keep working");
        Assert.False(page.CanClose());
        Assert.Equal("The ISO Builder is still working (Copying the ISO and reading its editions). Closing stops it; a half-built image is discarded the next time AkariOS starts.\n\nClose anyway?", t.Asked.Single());
        t.Answers.Enqueue("Close");
        Assert.True(page.CanClose());
        t.Work.Release();

        // a list job is only a question to a website: closing doesn't ask
        var (t2, page2) = ListJobRunning();
        Assert.True(page2.CanClose());
        Assert.Empty(t2.Asked);
    });

    [Fact]
    public void A_developer_build_leaves_AkariOS_out_saying_why() => LookTests.OnSta(() =>
    {
        var (t, page, view, _, fakes) = Opened();
        Assert.Null(t.S.AkariExe);
        Assert.False(page.AkariOS);
        Assert.False(page.AkariOSEnabled);
        Assert.Contains("developer build", page.AkariOSNote);
        t.Answers.Enqueue("Build ISO");
        Click(ButtonOf(view, "Build ISO"));
        Assert.Empty(fakes.Shortcuts);
        Assert.StartsWith("ISO ready: ", page.BuildResult);
    });
}
