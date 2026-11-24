using System.Text.Json;
using System.Text.RegularExpressions;
using AkariOS.Core.Apps;
using AkariOS.Core.Iso;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using AkariOS.Core.Update;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

/// <summary>
/// IsoBuild against src\Core\Iso.ps1 (Oracle/Invoke-IsoBuild.ps1): the real Open-AkariIsoSource, Mount-AkariIsoEdition,
/// Invoke-AkariIsoBuild and Clear-AkariIsoLeftover with recorders in place of every wrapper; IsoBuild with recording
/// fakes answering the same case. Each side has its own temp folder (the ISO drive, the output) and test key (the
/// image's hives). Compared: the ordered calls (one neutral vocabulary: DiskMount, WimImages, Export, Mount, Commit,
/// Discard, HiveLoad / HiveUnload, Read, Remove, Dism, Own, Trusted, Oscdimg), the log and akari.log lines, the
/// progress, each operation the build reports (stage, name, state, note), its report.json without timings, each
/// action's result, the marker left, the hives' registry state. The AkariOS step differs on purpose (an exe, not a
/// folder) and is left out here, its operation too (IsoBuildTests).
/// </summary>
public sealed partial class IsoBuildOracleTests
{
    // the case, Side, Json: IsoShared.cs

    // ---- what a side gives back

    internal sealed record Output(List<string> Calls, List<string> Log, List<string> ErrLog, List<string> Progress, List<string> Results, string Marker)
    {
        public List<string> Ops { get; init; } = [];
        public List<string> Report { get; init; } = [];
    }

    /// <summary>The AkariOS step's operation, named after what each app copies.</summary>
    private static readonly HashSet<string> AkariOSOps = ["AkariOS and its shortcuts", "AkariOS-Native.exe and its shortcuts"];

    /// <summary>A side's report.json as lines ('.stages[2].operations[0].state=Done'), without its times and the
    /// AkariOS operation; "(none)" when the build wrote none.</summary>
    internal static List<string> ReportLines(string root, Func<string, string> norm)
    {
        var file = Path.Combine(root, "out", "Win11-Akari.report.json");
        if (!File.Exists(file)) return ["(none)"];
        var lines = new List<string>();
        void Walk(JsonElement e, string at)
        {
            switch (e.ValueKind)
            {
                case JsonValueKind.Object:
                    if (e.TryGetProperty("name", out var n) && n.ValueKind == JsonValueKind.String && AkariOSOps.Contains(n.GetString()!)) return;
                    foreach (var p in e.EnumerateObject())
                        if (p.Name is not ("started" or "finished" or "seconds")) Walk(p.Value, $"{at}.{p.Name}");
                    break;
                case JsonValueKind.Array:
                    var i = 0;
                    foreach (var x in e.EnumerateArray()) Walk(x, $"{at}[{i++}]");
                    if (i == 0) lines.Add($"{at}=[]");
                    break;
                case JsonValueKind.String: lines.Add($"{at}={norm(e.GetString()!)}"); break;
                default: lines.Add($"{at}={e.GetRawText()}"); break;
            }
        }
        Walk(JsonDocument.Parse(File.ReadAllText(file)).RootElement, "");
        return lines;
    }

    private static bool NotAkariOS(string op) => !AkariOSOps.Contains(op.Split('|')[1]);

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
            Strings(r.GetProperty("Progress")), [.. r.GetProperty("Results").EnumerateArray().Select(Show)], r.GetProperty("Marker").GetString() ?? "")
        {
            Ops = [.. Strings(r.GetProperty("Ops")).Where(NotAkariOS)],
            Report = ReportLines(s.Root, x => x.Replace(s.Root, "<root>")),
        };
    }

    /// <param name="wizard">native only: the choices changed before the build (the wizard's groups, the AkariOS bake)</param>
    internal static Output Cs(Side s, Dictionary<string, object> c, Action<IsoFakes>? tune = null, Func<IsoChoices, IsoChoices>? wizard = null)
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
                        Apps = List("Apps"), Features = List("Features"), Capabilities = List("Capabilities"), Packages = List("Packages"),
                        AkariExe = ch.TryGetValue("AkariOS", out var ak) && ak is true ? f.MakeExe() : null,
                        Unattend = ch.TryGetValue("Unattend", out var u) ? System.Text.Encoding.UTF8.GetBytes((string)u) : null,
                        Settings = ch.TryGetValue("Settings", out var st) ? (IsoBuildSettings)st : new(),
                        // the wizard
                        Groups = ch.TryGetValue("Groups", out var gr) ? (string[])gr : null,
                        AppPatterns = ch.TryGetValue("AppPatterns", out var ap) ? (string[])ap : null,
                        FirstSignIn = ch.TryGetValue("FirstSignIn", out var fs) && fs is true,
                        ImageBuild = ch.TryGetValue("ImageBuild", out var ib) ? (int)ib : 0,
                        Bake = ch.TryGetValue("Bake", out var bk) ? [.. ((BakeCase[])bk).Select(x => new IsoBakeItem(Loaded.Value.First(t => t.Id == x.Id), x.Value))] : null,
                    };
                    if (wizard is not null) choices = wizard(choices);
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
        return new Output(f.Calls, [.. f.Log.Lines.Select(f.Norm)], [.. f.Log.FileLines.Select(f.Norm)], f.ProgressLines, results, marker)
        {
            Ops = [.. f.Ops.Select(o => f.Norm($"{o.Stage}|{o.Name}|{o.State}|{o.Note}")).Where(NotAkariOS)],
            Report = ReportLines(s.Root, f.Norm),
        };
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
        Assert.Equal(p.Ops, n.Ops);
        Assert.Equal(p.Report, n.Report);
        // the first sign-in's RunOnce command names each app's own program (AkariOS-Native.exe, Akari.ps1)
        static List<string> NoCommand(List<string> r) => [.. r.Select(l => l.Contains(@"\CurrentVersion\RunOnce|AkariOS|", StringComparison.Ordinal) ? l[..(l.LastIndexOf('|') + 1)] : l)];
        Assert.Equal(NoCommand(ps.Registry()), NoCommand(cs.Registry()));
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
    public void Builds_with_no_groups_or_lists()
    {
        var o = Same(Case());
        Assert.Equal(@"Action=Build;Ok=true;Path=<root>\out\Win11-Akari.iso;Message=", o.Results[1]);
        // the ISO's hash, and the report's
        var sha = Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData("iso"u8.ToArray()));
        Assert.Contains(o.Ops, x => x.EndsWith($"|SHA-256 of the ISO|Done|{sha}"));
        Assert.Contains($".sha256={sha}", o.Report);
        Assert.Contains(".size=3", o.Report);
        Assert.Contains(@"Oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b<root>\out\AkariIso\Media\boot\etfsboot.com#pEF,e,b<root>\out\AkariIso\Media\efi\microsoft\boot\efisys.bin <root>\out\AkariIso\Media <root>\out\Win11-Akari.iso", o.Calls);
        // nothing always on: boot.wim and the image's registry left alone
        Assert.DoesNotContain(@"Mount <root>\out\AkariIso\Media\sources\boot.wim 2 <root>\out\AkariIso\Mount", o.Calls);
        Assert.DoesNotContain(o.Calls, x => x.StartsWith("HiveLoad", StringComparison.Ordinal));
        Assert.Equal("", o.Marker);
    }

    /// <summary>A component store for Minimal's pruning: its metadata, the three runtimes it needs, one component.</summary>
    private static readonly string[] StoreFiles =
    [
        @"Windows\WinSxS\Manifests\a.manifest",
        @"Windows\WinSxS\amd64_microsoft.windows.common-controls_6595b64144ccf1df_6.0_none_1\comctl32.dll",
        @"Windows\WinSxS\amd64_microsoft.windows.gdiplus_6595b64144ccf1df_1.1_none_1\gdiplus.dll",
        @"Windows\WinSxS\amd64_microsoft-windows-servicingstack_31bf3856ad364e35_10.0_none_1\a.dll",
        @"Windows\WinSxS\amd64_microsoft-windows-notepad_31bf3856ad364e35_10.0_none_1\notepad.exe",
        @"Windows\System32\Recovery\winre.wim",
    ];

    public static TheoryData<string> GroupIds => [.. IsoWizard.Groups(new FolderSourceFiles(Repo.Root)).Select(g => g.Id)];

    [Theory]
    [MemberData(nameof(GroupIds))]
    public void Builds_with_each_group_alone(string id) => Same(Case(c =>
    {
        Choices(c)["Groups"] = new[] { id };
        c["ImageFiles"] = (string[])[.. ImageFiles, .. StoreFiles];
    }));

    [Fact]
    public void Builds_with_every_group_and_every_list_picked() => Same(Case(c =>
    {
        var ch = Choices(c);
        ch["Groups"] = IsoWizard.Groups(new FolderSourceFiles(Repo.Root)).Select(g => g.Id).ToArray();
        c["ImageFiles"] = (string[])[.. ImageFiles, .. StoreFiles];
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

    // ---- the wizard (native batch I4, PowerShell P7): removal groups instead of the always-on data, the AkariOS bake

    internal sealed record BakeCase(string Id, object? Value);

    private static readonly FolderSourceFiles RepoFiles = new(Repo.Root);
    private static readonly Lazy<IReadOnlyList<Tweak>> Loaded = new(() => new Loader(RepoFiles, new Dictionary<string, ITweakCode>()).Load().Tweaks);

    private static Dictionary<string, object> Mode(string id, Action<Dictionary<string, object>>? change = null) => Case(c =>
    {
        var m = IsoWizard.Modes(RepoFiles).Single(x => x.Id == id);
        var groups = IsoWizard.Picked(m.Groups, IsoWizard.Groups(RepoFiles));
        var ch = Choices(c);
        ch["Groups"] = m.Groups.ToArray();
        ch["AppPatterns"] = IsoWizard.AppPatterns(groups, Loaded.Value.Select(t => (t.Id, (string?)t.Risk.ToString(), t.Keep))).ToArray();
        ch["Settings"] = m.Settings;
        c["ImageFiles"] = (string[])[.. ImageFiles, @"Windows\System32\OneDriveSetup.exe", @"Program Files (x86)\Microsoft\Edge\a.exe", @"Program Files (x86)\Microsoft\EdgeWebView\b.dll"];
        c["ImageFeatures"] = new[] { "Windows-Defender-Default-Definitions", "Recall", "Printing-PrintToPDFServices-Features", "MediaPlayback", "WorkFolders-Client" };
        c["ImageCapabilities"] = new object[] { new { Name = "Media.WindowsMediaPlayer~~~~0.0.12.0", State = "Installed" }, new { Name = "App.StepsRecorder~~~~0.0.1.0", State = "NotPresent" } };
        change?.Invoke(c);
    });

    [Fact]
    public void Builds_the_lite_mode_from_its_groups() => Same(Mode("Lite"));

    [Fact]
    public void Builds_the_minimal_mode_and_prunes_the_component_store()
    {
        var o = Same(Mode("Minimal", c => c["ImageFiles"] = (string[])[.. (string[])c["ImageFiles"], .. StoreFiles]));
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Contains("Pruned 1 of 1 component folders", o.Log);
        Assert.Contains(o.Ops, x => x.EndsWith("|1 component folders|Done|1 removed; 4 kept"));
    }

    [Fact]
    public void Minimal_refuses_to_prune_an_image_with_pending_servicing() =>
        Same(Mode("Minimal", c => c["ImageFiles"] = (string[])[.. (string[])c["ImageFiles"], .. StoreFiles, IsoPlan.PendingXml]));

    [Fact]
    public void Minimal_refuses_to_prune_without_the_runtimes() =>
        Same(Mode("Minimal", c => c["ImageFiles"] = (string[])[.. (string[])c["ImageFiles"], .. StoreFiles.Where(f => !f.Contains("gdiplus", StringComparison.Ordinal))]));

    [Fact]
    public void Builds_the_akarios_mode_with_the_bake_and_the_first_sign_in()
    {
        var bake = IsoWizard.Bake(new PresetStore(RepoFiles, Path.GetTempPath(), Path.Combine(Path.GetTempPath(), "none.json"), new MemoryLog()).Find(IsoWizard.Preset)!,
            Loaded.Value, 26100);
        var o = Same(Mode("AkariOS", c =>
        {
            var ch = Choices(c);
            ch["AkariOS"] = true;
            ch["FirstSignIn"] = true;
            ch["ImageBuild"] = 26100;
            ch["Bake"] = bake.InImage.Select(x => new BakeCase(x.Tweak.Id, x.Value)).ToArray();
        }));
        Assert.Contains(o.Ops, x => x.EndsWith("|The rest of AkariOS at the first sign-in|Done|A RunOnce entry for each new account: one UAC prompt, then One-click's console"));
        Assert.Equal(bake.InImage.Count, o.Ops.Count(x => x.Contains("|Tweak ", StringComparison.Ordinal) && x.Contains("|Done|", StringComparison.Ordinal)));
    }

    [Fact]
    public void Fails_an_unknown_group_before_it_starts() => Same(Case(c => Choices(c)["Groups"] = new[] { "SkipHardwareChecks", "Nope" }));

    // ---- the build settings (native batch I3, PowerShell P6)

    private static Dictionary<string, object> WithSettings(IsoBuildSettings settings, Action<Dictionary<string, object>>? change = null) =>
        Case(x => { Choices(x)["Settings"] = settings; change?.Invoke(x); });

    [Theory]
    [InlineData(IsoCompression.Recovery)]
    [InlineData(IsoCompression.Fast)]
    public void Compresses_as_picked(IsoCompression compression)
    {
        var o = Same(WithSettings(new() { Compression = compression }));
        Assert.Contains($".settings.compression={compression}", o.Report);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(3010)]
    [InlineData(50)]
    public void Removes_the_features_in_one_dism_call_with_turbo(int code)
    {
        var o = Same(WithSettings(new() { Turbo = true }, x =>
        {
            Choices(x)["Features"] = new[] { "Recall", "Printing-PrintToPDFServices-Features", "Gone-Feature" };
            x["StuckFeatures"] = new[] { "Printing-PrintToPDFServices-Features" };
            ((Dictionary<string, int>)x["DismCodes"])["Disable-Feature"] = code;
        }));
        Assert.Contains(o.Ops, x => x.EndsWith($"|Windows feature Printing-PrintToPDFServices-Features|Failed|Still Enabled (DISM exit code {code})"));
        Assert.Contains(o.Ops, x => x.EndsWith("|Windows feature Gone-Feature|Done|Not in the image any more"));
    }

    [Fact]
    public void Removes_the_leftover_image_data_on_the_allow_list()
    {
        var o = Same(WithSettings(new() { CleanLeftovers = true }, x => x["ImageFiles"] = (string[])[.. ImageFiles,
            @"Windows\SoftwareDistribution\Download\abc\x.cab", @"Windows\Temp\t.tmp", @"Windows\Logs\CBS\CbsPersist_1.log", @"Windows\Logs\CBS\CBS.log", @"Windows\MEMORY.DMP"]));
        Assert.Contains(o.Ops, x => x.EndsWith(@"|Windows\Temp\*|Done|1 removed"));
        Assert.Contains(o.Ops, x => x.EndsWith(@"|Windows\Minidump\*|Skipped|Nothing there"));
    }

    [Fact]
    public void Keeps_the_leftover_data_while_servicing_is_pending() => Same(WithSettings(new() { CleanLeftovers = true },
        x => x["ImageFiles"] = (string[])[.. ImageFiles, @"Windows\Temp\t.tmp", IsoPlan.PendingXml]));

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Leaves_the_net35_setup_files_off_the_iso(bool noSxs) => Same(WithSettings(new() { LeaveOutNetFx3Files = true }, x => { if (noSxs) x["NoSxs"] = true; }));

    [Fact]
    public void Builds_with_every_setting_on() => Same(WithSettings(
        new() { Compression = IsoCompression.Recovery, Turbo = true, CleanLeftovers = true, LeaveOutNetFx3Files = true },
        x => Choices(x)["Features"] = new[] { "Recall" }));

    [Fact]
    public void Logs_the_dism_calls_that_fail_and_goes_on()
    {
        var o = Same(DismFailures());
        Assert.Contains("  DISM could not remove it (exit code 50)", o.Log);
        Assert.Contains("  DISM could not remove it (exit code 2)", o.Log);
        Assert.Contains(".NET Framework 3.5 was not added (DISM exit code 1)", o.Log);
        Assert.Contains("Removing capability Media.WindowsMediaPlayer~~~~0.0.12.0", o.Log);
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Contains(o.Ops, x => x.EndsWith("|Optional feature Media.WindowsMediaPlayer~~~~0.0.12.0|Done|Finishes when the new Windows first starts"));
        Assert.Contains(o.Ops, x => x.EndsWith("|.NET Framework 3.5|Failed|DISM exit code 1"));
    }

    private static Dictionary<string, object> DismFailures() => Case(c =>
    {
        var ch = Choices(c);
        ch["Features"] = new[] { "Windows-Defender-Default-Definitions" };
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
        Assert.Contains($@"Trusted {Store}\InboxApplications\Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe", o.Calls);
    }

    private static Dictionary<string, object> Denials() => Case(c =>
    {
        Choices(c)["Groups"] = new[] { "Tiny11Settings", "NoSponsoredApps", "WindowsAI" };
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
    public void A_failed_mount_fails_the_build_and_discards() => Same(Case(c => c["Fail"] = "Mount"));

    [Fact]
    public void A_failed_registry_write_fails_the_build_and_discards() => Same(Case(c => { c["Fail"] = "Trusted"; Choices(c)["Groups"] = new[] { "Tiny11Core" }; }));

    [Fact]
    public void A_failed_oscdimg_fails_the_build() => Same(Case(c => c["Fail"] = "Oscdimg"));
}

// IsoFakes: IsoShared.cs
