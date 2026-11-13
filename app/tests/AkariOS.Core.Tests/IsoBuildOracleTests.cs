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
public sealed class IsoBuildOracleTests
{
    // ---- the case

    internal static readonly string[] IsoFiles =
    [
        "setup.exe", @"sources\install.wim", @"sources\boot.wim", @"sources\sxs\microsoft-windows-netfx3.cab",
        @"boot\etfsboot.com", @"efi\microsoft\boot\efisys.bin",
    ];

    internal static readonly string[] ImageFiles =
    [
        @"Windows\System32\config\SOFTWARE", @"Windows\System32\config\SYSTEM", @"Windows\System32\config\DEFAULT", @"Users\Default\NTUSER.DAT",
        @"Windows\InboxApps\a.appx", @"Program Files\Internet Explorer\iexplore.exe", @"Windows\System32\UCPDMgr.exe",
        @"Windows\SystemApps\MicrosoftWindows.Client.AIX_cw5n1h2txyewy\a.dll", @"Program Files\Windows Defender\MsMpEng.exe",
        @"Program Files\WindowsApps\Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe\a.dll", @"Windows\SystemApps\Microsoft.BingNews_cw5n1h2txyewy\b.dll",
        @"Program Files\WindowsApps\Microsoft.SecHealthUI_1000.0.0.0_x64__8wekyb3d8bbwe\c.dll",
    ];

    private const string Store = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore";

    internal static Dictionary<string, object> Case(Action<Dictionary<string, object>>? change = null)
    {
        var media = @"<root>\out\AkariIso\Media\sources";
        var c = new Dictionary<string, object>
        {
            ["Actions"] = new[] { "Open", "Build" },
            ["Drive"] = new { Free = 30L << 30, Format = "NTFS" },
            ["Wims"] = new Dictionary<string, object[]>
            {
                [$@"{media}\install.wim"] = [new { Index = 1, Name = "Windows 11 Home", Version = "10.0.26100.1742" }, new { Index = 6, Name = "Windows 11 Pro", Version = "10.0.26100.1742" }],
                [$@"{media}\boot.wim"] = [new { Index = 1, Name = "Microsoft Windows PE", Version = "10.0.26100.1" }, new { Index = 2, Name = "Microsoft Windows Setup", Version = "10.0.26100.1" }],
            },
            ["ImageFiles"] = ImageFiles,
            ["BootFiles"] = new[] { @"Windows\System32\config\SOFTWARE", @"Windows\System32\config\SYSTEM" },
            ["ImageApps"] = new object[]
            {
                new { Name = "Microsoft.BingNews", Package = "Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.SecHealthUI", Package = "Microsoft.SecHealthUI_1000.0.0.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.Copilot", Package = "Microsoft.Copilot_1.0.0.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.VCLibs.140.00", Package = "Microsoft.VCLibs.140.00_14.0.0.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.WindowsCalculator", Package = "Microsoft.WindowsCalculator_11.0.0.0_x64__8wekyb3d8bbwe" },
            },
            ["ImageFeatures"] = new[] { "Windows-Defender-Default-Definitions", "Recall", "Printing-PrintToPDFServices-Features" },
            ["DismCodes"] = new Dictionary<string, int>(),
            ["Fail"] = "",
            ["Denied"] = Array.Empty<string>(),
            ["Choices"] = new Dictionary<string, object> { ["Index"] = 6, ["Edition"] = "Windows 11 Pro" },
        };
        change?.Invoke(c);
        return c;
    }

    internal static Dictionary<string, object> Choices(Dictionary<string, object> c) => (Dictionary<string, object>)c["Choices"];

    /// <summary>JSON with '&lt;root&gt;' kept as text (the default encoder writes <), so each side can put its own
    /// folder in.</summary>
    internal static string Json(object o) =>
        JsonSerializer.Serialize(o, new JsonSerializerOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping });

    // ---- one side's folders and test key

    internal sealed class Side : IDisposable
    {
        public string Root { get; } = Path.Combine(Path.GetTempPath(), $"akari-isob-{Guid.NewGuid():N}");
        public TestKey Key { get; } = new();

        public Side(Dictionary<string, object> c)
        {
            bool Without(string key) => c.TryGetValue(key, out var v) && v is true;
            foreach (var f in IsoFiles)
            {
                if ((Without("NoSxs") && f.Contains("sxs")) || (Without("NoInstall") && f.Contains("install")) || (Without("NoEtfs") && f.Contains("etfs"))) continue;
                var p = Path.Combine(Root, "drive", f);
                Directory.CreateDirectory(Path.GetDirectoryName(p)!);
                File.WriteAllText(p, "x");
                File.SetAttributes(p, FileAttributes.ReadOnly);
            }
            Directory.CreateDirectory(Path.Combine(Root, "out"));
            var reg = new RegistryEngine(Key.Paths);
            reg.SetValue($@"{IsoData.HiveRoot}SOFTWARE\Microsoft\Windows NT\CurrentVersion", Without("NoDisplayVersion") ? "ProductName" : "DisplayVersion", "24H2", "String");
            foreach (var k in new[] { "InboxApplications", "Applications", "Staged" })
                reg.SetValue($@"{IsoData.HiveRoot}{Store}\{k}\Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe", "Path", "x", "String");
            reg.SetValue($@"{IsoData.HiveRoot}{Store}\InboxApplications\MicrosoftWindows.Client.CoreAI_1000.0.0.0_x64__cw5n1h2txyewy", "Path", "x", "String");
            reg.SetValue($@"{IsoData.HiveRoot}{Store}\InboxApplications\Microsoft.WindowsCalculator_11.0.0.0_x64__8wekyb3d8bbwe", "Path", "x", "String");
            reg.SetValue($@"{IsoData.HiveRoot}NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions\1", "x", 1u, "DWord");
        }

        public void Dispose()
        {
            Key.Dispose();
            if (!Directory.Exists(Root)) return;
            foreach (var f in Directory.EnumerateFiles(Root, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
            Directory.Delete(Root, recursive: true);
        }

        /// <summary>The hives' state: every key and value under the test key's HKLM\AkariIso_*.</summary>
        public List<string> Registry()
        {
            var list = new List<string>();
            using var hkcu = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64);
            using var hklm = hkcu.OpenSubKey($@"{Key.Root}\HKLM");
            if (hklm is null) return list;
            void Walk(RegistryKey k, string at)
            {
                list.Add(at);
                foreach (var n in k.GetValueNames().Order(StringComparer.OrdinalIgnoreCase))
                {
                    var v = k.GetValue(n, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                    var text = v switch { byte[] b => Convert.ToHexString(b), string[] s => string.Join(",", s), _ => $"{v}" };
                    list.Add($"{at}|{n}|{k.GetValueKind(n)}|{text}");
                }
                foreach (var s in k.GetSubKeyNames().Order(StringComparer.OrdinalIgnoreCase))
                {
                    using var sub = k.OpenSubKey(s)!;
                    Walk(sub, $@"{at}\{s}");
                }
            }
            foreach (var s in hklm.GetSubKeyNames().Order(StringComparer.OrdinalIgnoreCase))
            {
                using var sub = hklm.OpenSubKey(s)!;
                Walk(sub, s);
            }
            return list;
        }
    }

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
                    var r = b.Build(choices, f.Progress);
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

/// <summary>The recording fakes behind IsoBuild in IsoBuildOracleTests (and IsoBuildTests): they answer the case as
/// Oracle/Invoke-IsoBuild.ps1's recorders do and write the same neutral calls.</summary>
internal sealed class IsoFakes : IImage, IOfflineHives, IDiskImage, IExe, ITrustedInstaller, IRegistryPaths, IShortcuts, IHttp
{
    private readonly IsoBuildOracleTests.Side _side;
    private readonly JsonElement _c;
    private readonly RedirectedRegistryPaths _inner;
    private readonly string[] _denied;
    private bool _inTrusted;

    public List<string> Calls { get; } = [];
    public List<string> Shortcuts { get; } = [];
    public List<string> Downloads { get; } = [];
    public List<string> ProgressLines { get; } = [];
    public MemoryLog Log { get; } = new();
    public IProgress<RunProgress> Progress { get; }
    public IsoParts Parts { get; set; }

    /// <summary>Called when oscdimg runs (IsoBuildTests: the media as it is then).</summary>
    public Action? OnOscdimg { get; set; }

    /// <summary>Called with the mount folder before a commit empties it.</summary>
    public Action<string>? OnCommit { get; set; }

    /// <summary>Called with any other program run (the ADK's setup).</summary>
    public Action<string, string>? OnExe { get; set; }

    /// <summary>How many unloads fail before they work.</summary>
    public int UnloadFailures { get; set; }

    public List<(string Path, string Args, bool Wait, bool Capture)> Runs { get; } = [];

    public IsoFakes(IsoBuildOracleTests.Side side, Dictionary<string, object> c)
    {
        _side = side;
        _c = JsonDocument.Parse(IsoBuildOracleTests.Json(c).Replace("<root>", side.Root.Replace(@"\", @"\\"))).RootElement;
        _inner = side.Key.Paths;
        _denied = [.. _c.GetProperty("Denied").EnumerateArray().Select(e => e.GetString()!)];
        Progress = new Recorder(p => ProgressLines.Add($"{p.Done}/{p.Total} {p.Step}"));
        var pf86 = Path.Combine(side.Root, "pf86");
        var oscdimg = Path.Combine(pf86, @"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(oscdimg)!);
        File.WriteAllText(oscdimg, "");
        var drive = _c.GetProperty("Drive");
        Parts = new IsoParts
        {
            Files = new FolderSourceFiles(Repo.Root), Image = this, Hives = this, Disk = this, Registry = new RegistryEngine(this, this), Trusted = this,
            Exe = this, Http = this, Shortcuts = this, Log = Log, Marker = Path.Combine(side.Root, "iso-mount.json"), Windows = @"C:\Windows",
            ProgramFilesX86 = pf86, Temp = Path.Combine(side.Root, "temp"), Drive = _ => (drive.GetProperty("Free").GetInt64(), drive.GetProperty("Format").GetString()!),
            Sleep = _ => { },
        };
    }

    private sealed class Recorder(Action<RunProgress> on) : IProgress<RunProgress>
    {
        public void Report(RunProgress value) => on(value);
    }

    public string Norm(string s) => s.Replace(_side.Root, "<root>");

    private void Rec(string s) => Calls.Add(Norm(s));

    private string Fail => _c.GetProperty("Fail").GetString()!;

    public string MakeExe()
    {
        var exe = Path.Combine(_side.Root, "akari", "AkariOS-Native.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(exe)!);
        File.WriteAllText(exe, "exe");
        return exe;
    }

    private static void ClearMount(string mount)
    {
        if (!Directory.Exists(mount)) return;
        foreach (var d in Directory.EnumerateDirectories(mount)) Directory.Delete(d, recursive: true);
        foreach (var f in Directory.EnumerateFiles(mount)) File.Delete(f);
    }

    private int Code(string verb) => _c.GetProperty("DismCodes").TryGetProperty(verb, out var v) ? v.GetInt32() : 0;

    // ---- IImage

    public IReadOnlyList<WimImage> Images(string wim)
    {
        Rec($"WimImages {wim}");
        return _c.GetProperty("Wims").TryGetProperty(wim, out var list)
            ? [.. list.EnumerateArray().Select(i => new WimImage(i.GetProperty("Index").GetInt32(), i.GetProperty("Name").GetString()!, i.GetProperty("Version").GetString()!))]
            : [];
    }

    public void Export(string source, int index, string dest, string compression)
    {
        Rec($"Export {source} {index} {dest} {compression}");
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        File.WriteAllText(dest, "");
    }

    public void Mount(string wim, int index, string mount)
    {
        Rec($"Mount {wim} {index} {mount}");
        if (Fail == "Mount") throw new InvalidOperationException("The image could not be mounted.");
        var files = Path.GetFileName(wim) == "boot.wim" ? "BootFiles" : "ImageFiles";
        foreach (var f in _c.GetProperty(files).EnumerateArray())
        {
            var p = Path.Combine(mount, f.GetString()!);
            Directory.CreateDirectory(Path.GetDirectoryName(p)!);
            File.WriteAllText(p, "");
        }
    }

    public void Commit(string mount) { Rec($"Commit {mount}"); OnCommit?.Invoke(mount); ClearMount(mount); }

    public void Discard(string mount) { Rec($"Discard {mount}"); ClearMount(mount); }

    public IReadOnlyList<ImageApp> ProvisionedApps(string mount)
    {
        Rec($"Read Apps {mount}");
        return [.. _c.GetProperty("ImageApps").EnumerateArray().Select(a => new ImageApp(a.GetProperty("Name").GetString()!, a.GetProperty("Package").GetString()!))];
    }

    public IReadOnlyList<DismItem> Features(string mount)
    {
        Rec($"Read Features {mount}");
        return [.. _c.GetProperty("ImageFeatures").EnumerateArray().Select(n => new DismItem(n.GetString()!, "Enabled"))];
    }

    public IReadOnlyList<DismItem> Capabilities(string mount) { Rec($"Read Capabilities {mount}"); return []; }

    public IReadOnlyList<DismItem> Packages(string mount) { Rec($"Read Packages {mount}"); return []; }

    public int Remove(string mount, string kind, string name)
    {
        Rec($"Remove {kind} {mount} {name}");
        return Code(kind switch { "Feature" => "Disable-Feature", "Capability" => "Remove-Capability", _ => "Remove-Package" });
    }

    public int Dism(IReadOnlyList<string> arguments)
    {
        Rec("Dism " + string.Join(" ", arguments));
        return Code(arguments[1].TrimStart('/'));
    }

    // ---- IOfflineHives, IDiskImage

    public bool Load(string name, string file) { Rec($"HiveLoad {name} {file}"); return true; }

    public bool Unload(string name)
    {
        Rec($"HiveUnload {name}");
        if (UnloadFailures <= 0) return true;
        UnloadFailures--;
        return false;
    }

    string IDiskImage.Mount(string iso) { Rec($"DiskMount {iso}"); return Path.Combine(_side.Root, "drive") + @"\"; }

    public void Dismount(string iso) => Rec($"DiskDismount {iso}");

    // ---- IExe: takeown = Own, icacls quiet, oscdimg recorded with its arguments

    public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true)
    {
        var name = Path.GetFileName(path).ToLowerInvariant();
        var args = Args(arguments);
        Runs.Add((path, arguments, wait, capture));
        switch (name)
        {
            case "takeown.exe": Rec($"Own {args[1]}"); return new ExeResult(0, "");
            case "icacls.exe": return new ExeResult(0, "");
            case "oscdimg.exe":
                OnOscdimg?.Invoke();
                Rec("Oscdimg " + string.Join(" ", args));
                return new ExeResult(Fail == "Oscdimg" ? 2 : 0, "");
            default: Rec($"Exe {name} {arguments}"); OnExe?.Invoke(path, arguments); return new ExeResult(0, "");
        }
    }

    /// <summary>A command line split back into its arguments (quotes around one that has spaces).</summary>
    public static List<string> Args(string line) =>
        [.. Regex.Matches(line, "\"([^\"]*)\"|(\\S+)").Select(m => m.Groups[1].Success ? m.Groups[1].Value : m.Groups[2].Value)];

    // ---- ITrustedInstaller: what is written meanwhile is recorded by Resolve

    void ITrustedInstaller.Run(Action work)
    {
        if (Fail == "Trusted") throw new InvalidOperationException("TrustedInstaller failed.");
        _inTrusted = true;
        try { work(); }
        finally { _inTrusted = false; }
    }

    // ---- IRegistryPaths: the test key; a denied path throws unless written as TrustedInstaller

    public RegKeyPath Resolve(string path)
    {
        var at = path.IndexOf("AkariIso_", StringComparison.Ordinal);
        var hive = at < 0 ? null : path[(at + 9)..].TrimEnd('\\');
        if (_inTrusted && hive is not null) Rec($"Trusted {hive}");
        else if (hive is not null && _denied.Any(d => hive.Equals(d, StringComparison.OrdinalIgnoreCase) || hive.StartsWith(d + @"\", StringComparison.OrdinalIgnoreCase)))
            throw new UnauthorizedAccessException("Requested registry access is not allowed.");
        return _inner.Resolve(path);
    }

    // ---- IShortcuts, IHttp

    public void Create(string link, string target, string? workingDirectory = null) =>
        Shortcuts.Add($"{Norm(link)}|{target}|{workingDirectory}");

    public void Download(string url, string file)
    {
        Downloads.Add($"{url}|{Norm(file)}");
        File.WriteAllText(file, "setup");
    }
}
