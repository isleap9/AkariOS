using System.Text.Json;
using System.Text.RegularExpressions;
using AkariOS.Core.Apps;
using AkariOS.Core.Iso;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Update;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

/// <summary>
/// IsoBuild against src\Core\Iso.ps1 (Oracle/Invoke-IsoBuild.ps1): the real Open-AkariIsoSource, Mount-AkariIsoEdition,
/// Invoke-AkariIsoBuild and Clear-AkariIsoLeftover with recorders in place of every wrapper; IsoBuild with recording
/// fakes answering the same case. Each side has its own temp folder (the ISO drive, the output) and test key (the
/// image's hives). Compared: the ordered calls (one neutral vocabulary: DiskMount, WimImages, Export, Mount, Commit,
/// Discard, HiveLoad / HiveUnload, Read, Remove, Dism, Own, Trusted, Oscdimg), the log and akari.log lines, the
/// progress, each action's result, the marker left, the hives' registry state. The AkariOS step differs on purpose
/// (an exe, not a folder) and is left out here (IsoBuildTests).
/// </summary>
public sealed partial class IsoBuildOracleTests
{
    // the case, Side, Json: IsoShared.cs

    // ---- what a side gives back

    internal sealed record Output(List<string> Calls, List<string> Log, List<string> ErrLog, List<string> Progress, List<string> Results, string Marker);

    private static string Show(JsonElement e) => string.Join(";", e.EnumerateObject().Select(p => $"{p.Name}=" + (p.Value.ValueKind switch
    {
        JsonValueKind.String => p.Value.GetString(),
        JsonValueKind.Array => string.Join(",", p.Value.EnumerateArray().Select(i => i.GetString())),
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        _ => p.Value.GetRawText(),
    })));

    private static List<string> Strings(JsonElement e) => [.. e.EnumerateArray().Select(i => i.GetString()!)];

    internal static Output Ps(Side s, Dictionary<string, object> c)
    {
        var file = Path.Combine(s.Root, "case.json");
        File.WriteAllText(file, Json(c));
        var r = Oracle.Run("Invoke-IsoBuild.ps1", ["-Src", Repo.Src, "-Case", file, "-Root", s.Root, "-Reg", s.Key.Real("HKLM", "AkariIso_")]);
        return new Output(Strings(r.GetProperty("Calls")).Where(x => x != "AkariOS").ToList(), Strings(r.GetProperty("Log")), Strings(r.GetProperty("ErrLog")),
            Strings(r.GetProperty("Progress")), [.. r.GetProperty("Results").EnumerateArray().Select(Show)], r.GetProperty("Marker").GetString() ?? "");
    }

    internal static Output Cs(Side s, Dictionary<string, object> c, Action<IsoFakes>? tune = null)
    {
        var f = new IsoFakes(s, c);
        tune?.Invoke(f);
        var b = new IsoBuild(f.Parts);
        var results = new List<string>();
        if (c.TryGetValue("Marker", out var m))
            File.WriteAllText(f.Parts.Marker, Json(m).Replace("<root>", s.Root.Replace(@"\", @"\\")));
        var outDir = Path.Combine(s.Root, "out");
        var iso = Path.Combine(s.Root, "Win11.iso");
        IsoSource? opened = null;
        var ch = Choices(c);
        string[] List(string k) => ch.TryGetValue(k, out var v) ? (string[])v : [];
        foreach (var a in (string[])c["Actions"])
        {
            switch (a)
            {
                case "Open":
                    try
                    {
                        opened = b.Open(iso, outDir);
                        results.Add($"Action=Open;Error=;Image={f.Norm(opened.Image)};Editions=" +
                            string.Join(",", opened.Editions.Select(e => $"{e.Index}|{e.Name}|{e.Version}|{(e.Supported ? "True" : "False")}")));
                    }
                    catch (IsoException e) { results.Add($"Action=Open;Error={f.Norm(e.Message)};Image=;Editions="); }
                    break;
                case "Mount":
                    var err = "";
                    try { b.MountEdition(opened!.Work, opened.Image, (int)ch["Index"]); }
                    catch (Exception e) { err = f.Norm(e.Message); }
                    results.Add($"Action=Mount;Error={err}");
                    break;
                case "Build":
                    var choices = new IsoChoices
                    {
                        OutDir = outDir, Iso = iso, Image = opened?.Image ?? "", Index = (int)ch["Index"], Edition = (string)ch["Edition"],
                        Options = List("Options"), Apps = List("Apps"), Features = List("Features"), Capabilities = List("Capabilities"), Packages = List("Packages"),
                        AkariExe = ch.TryGetValue("AkariOS", out var ak) && ak is true ? f.MakeExe() : null,
                        Unattend = ch.TryGetValue("Unattend", out var u) ? System.Text.Encoding.UTF8.GetBytes((string)u) : null,
                    };
                    var r = b.Build(choices, f.Progress, f.Operations);
                    f.Report = r.Report;
                    results.Add($"Action=Build;Ok={(r.Ok ? "true" : "false")};Path={f.Norm(r.Path ?? "")};Message={f.Norm(r.Message)}");
                    break;
                case "Leftover":
                    b.ClearLeftover();
                    results.Add("Action=Leftover");
                    break;
            }
        }
        var marker = "";
        if (File.Exists(f.Parts.Marker))
        {
            var j = JsonDocument.Parse(File.ReadAllText(f.Parts.Marker)).RootElement;
            marker = f.Norm($"{j.GetProperty("Mount").GetString()}|{j.GetProperty("Image").GetString()}|{j.GetProperty("Index").GetRawText()}");
        }
        return new Output(f.Calls, [.. f.Log.Lines.Select(f.Norm)], [.. f.Log.FileLines.Select(f.Norm)], f.ProgressLines, results, marker);
    }

    private static Output Same(Dictionary<string, object> c)
    {
        using var ps = new Side(c);
        using var cs = new Side(c);
        var p = Ps(ps, c);
        var n = Cs(cs, c);
        Assert.Equal(p.ErrLog, n.ErrLog);
        Assert.Equal(p.Results, n.Results);
        Assert.Equal(p.Calls, n.Calls);
        Assert.Equal(p.Log, n.Log);
        Assert.Equal(p.ErrLog, n.ErrLog);
        Assert.Equal(p.Progress, n.Progress);
        Assert.Equal(p.Marker, n.Marker);
        Assert.Equal(ps.Registry(), cs.Registry());
        return n;
    }

    // ---- Open-AkariIsoSource

    [Fact]
    public void Opens_an_iso_as_powershell() => Same(Case(c => c["Actions"] = new[] { "Open" }));

    [Fact]
    public void Refuses_an_iso_without_an_install_image() => Same(Case(c => { c["Actions"] = new[] { "Open" }; c["NoInstall"] = true; }));

    [Fact]
    public void Refuses_an_iso_that_is_not_windows_11() => Same(Case(c =>
    {
        c["Actions"] = new[] { "Open" };
        ((Dictionary<string, object[]>)c["Wims"])[@"<root>\out\AkariIso\Media\sources\install.wim"] = [new { Index = 1, Name = "Windows 10 Pro", Version = "10.0.19045.2965" }];
    }));

    [Fact]
    public void Refuses_a_drive_that_is_too_small() => Same(Case(c => { c["Actions"] = new[] { "Open" }; c["Drive"] = new { Free = 10L << 30, Format = "NTFS" }; }));

    [Fact]
    public void Refuses_a_drive_that_is_not_ntfs() => Same(Case(c => { c["Actions"] = new[] { "Open" }; c["Drive"] = new { Free = 60L << 30, Format = "exFAT" }; }));

    [Fact]
    public void Discards_a_leftover_mount_on_launch() => Same(Case(c =>
    {
        c["Actions"] = new[] { "Leftover" };
        c["Marker"] = new { Mount = @"<root>\out\AkariIso\Mount", Image = @"<root>\out\AkariIso\Media\sources\install.wim", Index = 6 };
    }));

    [Fact]
    public void Does_nothing_without_a_leftover() => Same(Case(c => c["Actions"] = new[] { "Leftover" }));

    [Fact]
    public void Opening_discards_a_leftover_first() => Same(Case(c =>
    {
        c["Actions"] = new[] { "Open" };
        c["Marker"] = new { Mount = @"<root>\old\Mount", Image = "", Index = 0 };
    }));

    // ---- Mount-AkariIsoEdition

    [Fact]
    public void Mounts_an_edition_once() => Same(Case(c => c["Actions"] = new[] { "Open", "Mount", "Mount", "Build" }));

    [Fact]
    public void A_failed_mount_is_discarded() => Same(Case(c => { c["Actions"] = new[] { "Open", "Mount" }; c["Fail"] = "Mount"; }));

    // ---- Invoke-AkariIsoBuild

    [Fact]
    public void Builds_with_no_options()
    {
        var o = Same(Case());
        Assert.Equal(@"Action=Build;Ok=true;Path=<root>\out\Win11-Akari.iso;Message=", o.Results[1]);
        Assert.Contains(@"Oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b<root>\out\AkariIso\Media\boot\etfsboot.com#pEF,e,b<root>\out\AkariIso\Media\efi\microsoft\boot\efisys.bin <root>\out\AkariIso\Media <root>\out\Win11-Akari.iso", o.Calls);
        Assert.Contains(@"Mount <root>\out\AkariIso\Media\sources\boot.wim 2 <root>\out\AkariIso\Mount", o.Calls);
        Assert.Contains(@"Own <root>\out\AkariIso\Mount\Windows\InboxApps", o.Calls);
        Assert.Contains(@"Trusted SOFTWARE\Microsoft\Windows\CurrentVersion\Shell\ShellUIHosts\CrossDeviceResumeHost", o.Calls);
        Assert.Equal("", o.Marker);
    }

    public static TheoryData<string> OptionIds => [.. IsoData.Options(new FolderSourceFiles(Repo.Root)).Select(o => o.Id)];

    [Theory]
    [MemberData(nameof(OptionIds))]
    public void Builds_with_each_option_alone(string id) => Same(Case(c => Choices(c)["Options"] = new[] { id }));

    /// <summary>Every option that goes with the ones before it, in page order.</summary>
    private static string[] AllOptions()
    {
        var all = IsoData.Options(new FolderSourceFiles(Repo.Root));
        var picked = new List<string>();
        foreach (var o in all) if (IsoData.Check([.. picked, o.Id], all) is null) picked.Add(o.Id);
        return [.. picked];
    }

    [Fact]
    public void Builds_with_every_option_and_every_list_picked() => Same(Case(c =>
    {
        var ch = Choices(c);
        ch["Options"] = AllOptions();
        ch["Apps"] = new[] { "Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe", "Microsoft.SecHealthUI_1000.0.0.0_x64__8wekyb3d8bbwe" };
        ch["Features"] = new[] { "Printing-PrintToPDFServices-Features", "Recall" };
        ch["Capabilities"] = new[] { "Media.WindowsMediaPlayer~~~~0.0.12.0", "App.StepsRecorder~~~~0.0.1.0" };
        ch["Packages"] = new[] { "Microsoft-Windows-Hello-Face-Package~31bf3856ad364e35~amd64~~10.0.26100.1" };
    }));

    [Fact]
    public void Adds_akarios_and_the_answer_file() => Same(Case(c =>
    {
        Choices(c)["AkariOS"] = true;
        Choices(c)["Unattend"] = "<unattend/>";
    }));

    [Fact]
    public void Leaves_net35_out_without_sources_sxs() => Same(Case(c => c["NoSxs"] = true));

    [Fact]
    public void Leaves_boot_wim_alone_with_one_image() => Same(Case(c =>
        ((Dictionary<string, object[]>)c["Wims"])[@"<root>\out\AkariIso\Media\sources\boot.wim"] = [new { Index = 1, Name = "Microsoft Windows PE", Version = "10.0.26100.1" }]));

    [Fact]
    public void Boots_uefi_only_without_etfsboot() => Same(Case(c => c["NoEtfs"] = true));

    [Fact]
    public void Logs_the_dism_calls_that_fail_and_goes_on()
    {
        var o = Same(DismFailures());
        Assert.Contains("  DISM could not remove it (exit code 50)", o.Log);
        Assert.Contains("  DISM could not remove it (exit code 2)", o.Log);
        Assert.Contains(".NET Framework 3.5 was not added (DISM exit code 1)", o.Log);
        Assert.Contains("Removing capability Media.WindowsMediaPlayer~~~~0.0.12.0", o.Log);
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
    }

    private static Dictionary<string, object> DismFailures() => Case(c =>
    {
        var ch = Choices(c);
        ch["Options"] = new[] { "RemoveDefender" };
        ch["Apps"] = new[] { "Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe" };
        ch["Capabilities"] = new[] { "Media.WindowsMediaPlayer~~~~0.0.12.0" };
        ch["Packages"] = new[] { "Some-Package~31bf3856ad364e35~amd64~~1.0" };
        c["DismCodes"] = new Dictionary<string, int>
        {
            ["Disable-Feature"] = 50, ["Remove-Capability"] = 3010, ["Remove-Package"] = -2146498555, ["Remove-ProvisionedAppxPackage"] = 2,
            ["Enable-Feature"] = 1, ["Cleanup-Image"] = 5,
        };
    });

    [Fact]
    public void Writes_denied_rows_and_keys_as_trustedinstaller()
    {
        var o = Same(Denials());
        Assert.Contains(@"Trusted SOFTWARE\Policies\Microsoft\Windows\DataCollection", o.Calls);
        Assert.Contains(@"Trusted NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions", o.Calls);
        Assert.Contains($@"Trusted {Store}\InboxApplications\MicrosoftWindows.Client.CoreAI_1000.0.0.0_x64__cw5n1h2txyewy", o.Calls);
        Assert.Contains($@"Trusted {Store}\InboxApplications\Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe", o.Calls);
    }

    private static Dictionary<string, object> Denials() => Case(c =>
    {
        Choices(c)["Options"] = new[] { "DisableTelemetry", "RemoveAI" };
        Choices(c)["Apps"] = new[] { "Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe" };
        c["Denied"] = new[]
        {
            // the keys themselves, not their parent: the build reads the parent's subkeys
            @"SOFTWARE\Policies\Microsoft\Windows\DataCollection", $@"{Store}\InboxApplications\Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe",
            $@"{Store}\InboxApplications\MicrosoftWindows.Client.CoreAI_1000.0.0.0_x64__cw5n1h2txyewy",
            @"NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions",
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace",
        };
    });

    [Fact]
    public void Leaves_out_display_version_when_the_image_has_none() => Same(Case(c =>
    {
        Choices(c)["Options"] = new[] { "DisableVersionUpgrade" };
        c["NoDisplayVersion"] = true;
    }));

    [Fact]
    public void A_failed_mount_fails_the_build_and_discards() => Same(Case(c => c["Fail"] = "Mount"));

    [Fact]
    public void A_failed_registry_write_fails_the_build_and_discards() => Same(Case(c => c["Fail"] = "Trusted"));

    [Fact]
    public void A_failed_oscdimg_fails_the_build() => Same(Case(c => c["Fail"] = "Oscdimg"));

    [Fact]
    public void Refuses_options_that_exclude_each_other() => Same(Case(c => Choices(c)["Options"] = new[] { "DisableUpdates", "SecurityOnly" }));
}

// IsoFakes: IsoShared.cs
