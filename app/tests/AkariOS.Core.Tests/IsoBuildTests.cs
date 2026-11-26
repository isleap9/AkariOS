using AkariOS.Core.Apps;
using AkariOS.Core.Iso;
using static AkariOS.Core.Tests.IsoBuildOracleTests;

namespace AkariOS.Core.Tests;

/// <summary>IsoBuild where the native app differs on purpose from the port or the oracle leaves it out: AkariOS as the
/// running exe, the answer file, the ADK's setup, the hive unload retries, the image reads.</summary>
public sealed class IsoBuildTests
{
    [Fact]
    public void Copies_the_running_exe_into_the_image_with_its_shortcuts()
    {
        var c = Case(x => Choices(x)["AkariOS"] = true);
        using var s = new Side(c);
        var copied = "";
        IsoFakes? fakes = null;
        var o = Cs(s, c, f =>
        {
            fakes = f;
            f.OnCommit = mount =>
            {
                var exe = Path.Combine(mount, "AkariOS", "AkariOS-Native.exe");
                if (copied.Length == 0 && File.Exists(exe)) copied = File.ReadAllText(exe);
            };
        });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Equal("exe", copied);
        Assert.Equal(
        [
            @"<root>\out\AkariIso\Mount\ProgramData\Microsoft\Windows\Start Menu\Programs\AkariOS.lnk|C:\AkariOS\AkariOS-Native.exe|C:\AkariOS",
            @"<root>\out\AkariIso\Mount\Users\Public\Desktop\AkariOS.lnk|C:\AkariOS\AkariOS-Native.exe|C:\AkariOS",
        ], fakes!.Shortcuts);
        Assert.Contains("Adding AkariOS to the image", o.Log);
    }

    [Fact]
    public void Leaves_akarios_out_without_an_exe()
    {
        var c = Case();
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => fakes = f);
        Assert.DoesNotContain("Adding AkariOS to the image", o.Log);
        Assert.Empty(fakes!.Shortcuts);
    }

    [Fact]
    public void Puts_the_answer_file_at_the_root_of_the_iso()
    {
        var c = Case(x => Choices(x)["Unattend"] = "<unattend/>");
        using var s = new Side(c);
        var answer = "";
        Cs(s, c, f => f.OnOscdimg = () => answer = File.ReadAllText(Path.Combine(s.Root, @"out\AkariIso\Media\autounattend.xml")));
        Assert.Equal("<unattend/>", answer);
    }

    [Fact]
    public void Installs_the_adk_deployment_tools_when_oscdimg_is_missing()
    {
        var c = Case();
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f =>
        {
            fakes = f;
            var oscdimg = Path.Combine(f.Parts.ProgramFilesX86, @"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe");
            File.Delete(oscdimg);
            f.OnExe = (path, _) => { if (Path.GetFileName(path) == "akari-adksetup.exe") File.WriteAllText(oscdimg, ""); };
        });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Equal([@"https://go.microsoft.com/fwlink/?linkid=2196127|<root>\temp\akari-adksetup.exe"], fakes!.Downloads);
        var setup = fakes.Runs.Single(r => Path.GetFileName(r.Path) == "akari-adksetup.exe");
        Assert.Equal("/quiet /norestart /features OptionId.DeploymentTools", setup.Args);
        Assert.True(setup.Wait);
        Assert.False(setup.Capture);
        Assert.False(File.Exists(Path.Combine(s.Root, @"temp\akari-adksetup.exe")));
        Assert.Single(o.Calls, x => x.StartsWith("Oscdimg ", StringComparison.Ordinal));
    }

    [Fact]
    public void Fails_before_mounting_when_the_adk_will_not_install()
    {
        var c = Case();
        using var s = new Side(c);
        var o = Cs(s, c, f => File.Delete(Path.Combine(f.Parts.ProgramFilesX86, @"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe")));
        Assert.Equal("Action=Build;Ok=false;Path=;Message=The Windows ADK Deployment Tools did not install (oscdimg.exe is missing).", o.Results[1]);
        Assert.DoesNotContain(o.Calls, x => x.StartsWith("Mount ", StringComparison.Ordinal));
    }

    [Fact]
    public void Reports_progress_per_step_then_done()
    {
        var c = Case();
        using var s = new Side(c);
        var o = Cs(s, c);
        // Adk, Mount, NetFx3, Cleanup, Commit, Compress, Iso, Tidy
        Assert.Equal("0/8 Getting the ISO tool ready (Windows ADK)", o.Progress[0]);
        Assert.Equal("1/8 Mounting Windows 11 Pro", o.Progress[1]);
        Assert.Equal("7/8 Removing the work folder", o.Progress[7]);
        Assert.Equal("8/8 Done", o.Progress[^1]);
        Assert.Equal(9, o.Progress.Count);
    }

    [Fact]
    public void Tries_a_hive_unload_three_times_with_a_pause()
    {
        var c = Case(x => x["Actions"] = new[] { "Leftover" });
        c["Marker"] = new { Mount = @"<root>\m", Image = "", Index = 0 };
        using var s = new Side(c);
        var sleeps = new List<int>();
        var o = Cs(s, c, f => { f.UnloadFailures = 3; f.Parts = f.Parts with { Sleep = sleeps.Add }; });
        Assert.Equal(["HiveUnload SOFTWARE", "HiveUnload SOFTWARE", "HiveUnload SOFTWARE", "HiveUnload SYSTEM"], o.Calls.Take(4));
        Assert.Equal([500, 500], sleeps);
    }

    [Fact]
    public void Lists_the_image_apps_without_frameworks_and_only_installed_capabilities()
    {
        var c = Case();
        using var s = new Side(c);
        var f = new IsoFakes(s, c);
        var b = new IsoBuild(f.Parts);
        Assert.Equal(["Microsoft.BingNews", "Microsoft.SecHealthUI", "Microsoft.Copilot", "Microsoft.WindowsCalculator"], b.Apps("m").Select(a => a.Name));
        var image = new CapabilitiesImage(f);
        Assert.Equal(["A"], new IsoBuild(f.Parts with { Image = image }).Capabilities("m").Select(x => x.Name));
        Assert.Equal(["A"], new IsoBuild(f.Parts with { Image = image }).Items("m").Capabilities.Select(x => x.Name));
    }

    [Fact]
    public void Reports_each_removal_as_an_operation_and_writes_the_report_next_to_the_iso()
    {
        var c = Case(x => Choices(x)["Features"] = new[] { "Recall" });
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => fakes = f);
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);

        // each operation Running, then how it ended, under its step's index
        var steps = IsoPlan.Steps(new IsoChoices { Features = ["Recall"], Edition = "Windows 11 Pro" }, []);
        var feature = steps.ToList().FindIndex(x => x.Id == "Features");
        var recall = fakes!.Ops.Where(x => x.Name == "Windows feature Recall").ToList();
        Assert.Equal([IsoOpState.Running, IsoOpState.Done], recall.Select(x => x.State));
        Assert.All(recall, x => Assert.Equal(feature, x.Stage));
        Assert.Contains(fakes.Ops, x => x.Name == "SHA-256 of the ISO" && x.State != IsoOpState.Running);

        // the report: every stage done in order, its operations, the ISO's hash
        var iso = Path.Combine(s.Root, "out", "Win11-Akari.iso");
        var file = Path.Combine(s.Root, "out", "Win11-Akari.report.json");
        Assert.True(File.Exists(file));
        var report = IsoReport.FromJson(File.ReadAllText(file))!;
        Assert.True(report.Ok);
        Assert.Equal(iso, report.Iso);
        Assert.Equal("Windows 11 Pro", report.Edition);
        Assert.All(report.Stages, x => Assert.Equal("Done", x.State));
        Assert.Contains(report.Stages, x => x.Id == "Features" && x.Operations.Single().Name == "Windows feature Recall");
        Assert.Equal(IsoReport.Sha256Of(iso), report.Sha256);
        Assert.Equal(report.Sha256, fakes.Report!.Sha256);
    }

    [Fact]
    public void A_failed_build_reports_the_failed_stage_and_what_did_not_run()
    {
        var c = Case(x => x["Fail"] = "Oscdimg");
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => fakes = f);
        Assert.StartsWith("Action=Build;Ok=false", o.Results[1]);
        var report = fakes!.Report!;
        Assert.False(report.Ok);
        Assert.NotEmpty(report.Message);
        Assert.Equal("Failed", report.Stages.Single(x => x.Id == "Iso").State);
        Assert.Equal("Not run", report.Stages.Single(x => x.Id == "Tidy").State);
        Assert.All(report.Stages.TakeWhile(x => x.Id != "Iso"), x => Assert.Equal("Done", x.State));
        Assert.True(File.Exists(Path.Combine(s.Root, "out", "Win11-Akari.report.json")));
    }

    [Fact]
    public void Copies_each_image_apps_logo_out_of_the_mounted_image()
    {
        var c = Case();
        using var s = new Side(c);
        var mount = Path.Combine(s.Root, "mount");
        var app = Path.Combine(mount, "Program Files", "WindowsApps", "Microsoft.BingNews_1.0_x64__8wekyb3d8bbwe");
        Directory.CreateDirectory(Path.Combine(app, "Assets"));
        File.WriteAllText(Path.Combine(app, "AppxManifest.xml"),
            """<Package xmlns="x"><Applications><Application><VisualElements Square44x44Logo="Assets\Small.png" /></Application></Applications></Package>""");
        File.WriteAllText(Path.Combine(app, "Assets", "Small.scale-100.png"), "logo");
        var logos = new IsoBuild(new IsoFakes(s, c).Parts).AppLogos(mount,
            [new("Microsoft.BingNews", "Microsoft.BingNews_1.0_x64__8wekyb3d8bbwe"), new("Microsoft.Missing", "Microsoft.Missing_1.0_x64__8wekyb3d8bbwe")],
            Path.Combine(s.Root, "logos"));
        Assert.Equal(["Microsoft.BingNews"], logos.Keys);
        Assert.Equal(Path.Combine(s.Root, "logos", "Microsoft.BingNews.png"), logos["Microsoft.BingNews"]);
        Assert.Equal("logo", File.ReadAllText(logos["Microsoft.BingNews"]));
    }

    // ---- the build settings (batch I3, native only)

    private static Dictionary<string, object> WithSettings(IsoBuildSettings settings, Action<Dictionary<string, object>>? change = null) =>
        Case(x => { Choices(x)["Settings"] = settings; change?.Invoke(x); });

    [Fact]
    public void The_default_settings_build_as_the_port_does()
    {
        var c = Case();
        var steps = IsoPlan.Steps(new IsoChoices { Edition = "Windows 11 Pro" }, []);
        Assert.DoesNotContain(steps, x => x.Id is "Leftovers" or "NoSxs");
        Assert.Contains(steps, x => x.Text == "Compressing install.wim");
        using var s = new Side(c);
        IsoFakes? fakes = null;
        Cs(s, c, f => fakes = f);
        Assert.Contains(fakes!.Calls, x => x.StartsWith("Export ", StringComparison.Ordinal) && x.EndsWith(@"\Media\sources\install.wim max", StringComparison.Ordinal));
        Assert.Equal(new IsoBuildSettings(), fakes.Report!.Settings);
    }

    [Theory]
    [InlineData(IsoCompression.Recovery, "install.esd recovery", "Compressing install.esd (recovery compression)")]
    [InlineData(IsoCompression.Fast, "install.wim fast", "Compressing install.wim (fast compression)")]
    public void Compresses_as_picked(IsoCompression compression, string export, string text)
    {
        var c = WithSettings(new() { Compression = compression });
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => fakes = f);
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Contains(fakes!.Calls, x => x.StartsWith("Export ", StringComparison.Ordinal) && x.EndsWith(@"\Media\sources\" + export, StringComparison.Ordinal));
        Assert.Contains(text, o.Log);
        Assert.Equal(compression, fakes.Report!.Settings.Compression);
    }

    [Fact]
    public void Turbo_removes_the_features_in_one_dism_call_and_reads_each_back()
    {
        var c = WithSettings(new() { Turbo = true }, x =>
        {
            Choices(x)["Features"] = new[] { "Recall", "Printing-PrintToPDFServices-Features", "Gone-Feature" };
            x["StuckFeatures"] = new[] { "Printing-PrintToPDFServices-Features" };
        });
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => fakes = f);
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.DoesNotContain(fakes!.Calls, x => x.StartsWith("Remove Feature", StringComparison.Ordinal));
        Assert.Single(fakes.Calls, x => x.StartsWith("Dism /Image:", StringComparison.Ordinal) && x.Contains("/Disable-Feature", StringComparison.Ordinal) &&
            x.EndsWith("/FeatureName:Recall /FeatureName:Printing-PrintToPDFServices-Features /FeatureName:Gone-Feature /Remove /NoRestart", StringComparison.Ordinal));
        var ended = fakes.Ops.Where(x => x.State != IsoOpState.Running && x.Name.StartsWith("Windows feature ", StringComparison.Ordinal)).ToDictionary(x => x.Name, x => x.State);
        Assert.Equal(IsoOpState.Done, ended["Windows feature Recall"]);
        Assert.Equal(IsoOpState.Failed, ended["Windows feature Printing-PrintToPDFServices-Features"]);
        Assert.Equal(IsoOpState.Done, ended["Windows feature Gone-Feature"]);
        Assert.Contains("Removing 3 Windows features at once", o.Log);
        Assert.Contains("  Printing-PrintToPDFServices-Features is still Enabled", o.Log);
    }

    [Fact]
    public void Removes_the_leftover_image_data_on_the_allow_list_only()
    {
        string[] leftovers = [@"Windows\SoftwareDistribution\Download\abc\x.cab", @"Windows\Temp\t.tmp", @"Windows\Logs\CBS\CbsPersist_1.log",
            @"ProgramData\Microsoft\Windows\WER\ReportQueue\r\a.wer", @"Windows\MEMORY.DMP"];
        string[] kept = [@"Windows\Logs\CBS\CBS.log", @"Windows\SoftwareDistribution\DataStore\DataStore.edb"];
        var c = WithSettings(new() { CleanLeftovers = true }, x => x["ImageFiles"] = (string[])[.. ImageFiles, .. leftovers, .. kept]);
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var left = new List<string>();
        var o = Cs(s, c, f =>
        {
            fakes = f;
            f.OnCommit = m => { if (left.Count == 0) left.AddRange(leftovers.Concat(kept).Where(x => File.Exists(Path.Combine(m, x)))); };
        });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Equal(kept, left);
        Assert.Contains("Removing leftover image data", o.Log);
        Assert.Equal(IsoPlan.Leftovers, fakes!.Ops.Where(x => x.State != IsoOpState.Running && IsoPlan.Leftovers.Contains(x.Name)).Select(x => x.Name));
        Assert.Contains(fakes.Ops, x => x.Name == @"Windows\Temp\*" && x.State == IsoOpState.Done);
        Assert.Contains(fakes.Ops, x => x.Name == @"Windows\Minidump\*" && x.State == IsoOpState.Skipped);
    }

    [Fact]
    public void Keeps_the_leftover_data_while_servicing_is_pending()
    {
        var c = WithSettings(new() { CleanLeftovers = true }, x => x["ImageFiles"] = (string[])[.. ImageFiles, @"Windows\Temp\t.tmp", IsoPlan.PendingXml]);
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var kept = false;
        var o = Cs(s, c, f =>
        {
            fakes = f;
            f.OnCommit = m => kept |= File.Exists(Path.Combine(m, @"Windows\Temp\t.tmp"));
        });
        Assert.True(kept);
        Assert.Contains("The image has pending servicing (pending.xml): leftover data kept", o.Log);
        Assert.Single(fakes!.Ops, x => x.Name == "Leftover image data" && x.State == IsoOpState.Skipped);
    }

    [Fact]
    public void Leaves_the_net35_setup_files_off_the_iso_after_adding_net35()
    {
        var c = WithSettings(new() { LeaveOutNetFx3Files = true });
        using var s = new Side(c);
        var sxs = Path.Combine(s.Root, @"out\AkariIso\Media\sources\sxs");
        bool? onIso = null;
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => { fakes = f; f.OnOscdimg = () => onIso = Directory.Exists(sxs); });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.False(onIso);
        // .NET 3.5 is still added from it first
        Assert.Contains(fakes!.Calls, x => x.Contains("/FeatureName:NetFx3", StringComparison.Ordinal));
        var steps = IsoPlan.Steps(new IsoChoices { Settings = new() { LeaveOutNetFx3Files = true } }, []).Select(x => x.Id).ToList();
        Assert.True(steps.IndexOf("NetFx3") < steps.IndexOf("NoSxs") && steps.IndexOf("NoSxs") < steps.IndexOf("Iso"));
        Assert.True(fakes.Report!.Settings.LeaveOutNetFx3Files);
    }

    [Fact]
    public void Says_the_settings_as_review_lines() => Assert.Equal(
        ["Compression: Recovery ESD (smallest, slowest)", "Turbo feature removal: On", "Remove leftover image data: Off", ".NET 3.5's setup files on the ISO: Kept", "This PC's drivers: Not added"],
        new IsoBuildSettings { Compression = IsoCompression.Recovery, Turbo = true }.Lines());

    private sealed class CapabilitiesImage(IImage inner) : IImage
    {
        public IReadOnlyList<WimImage> Images(string wim) => inner.Images(wim);
        public void Export(string source, int index, string dest, string compression) => inner.Export(source, index, dest, compression);
        public void Mount(string wim, int index, string mount) => inner.Mount(wim, index, mount);
        public void Commit(string mount) => inner.Commit(mount);
        public void Discard(string mount) => inner.Discard(mount);
        public IReadOnlyList<ImageApp> ProvisionedApps(string mount) => inner.ProvisionedApps(mount);
        public IReadOnlyList<DismItem> Features(string mount) => inner.Features(mount);
        public IReadOnlyList<DismItem> Capabilities(string mount) => [new("A", "Installed"), new("B", "NotPresent"), new("C", "Staged")];
        public IReadOnlyList<DismItem> Packages(string mount) => inner.Packages(mount);
        public int Remove(string mount, string kind, string name) => inner.Remove(mount, kind, name);
        public int Dism(IReadOnlyList<string> arguments) => inner.Dism(arguments);
    }
}
