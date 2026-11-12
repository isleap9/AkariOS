using System.IO.Compression;
using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Tools;

/// <summary>Tools › Refresh's restart to BIOS and Tools › Drivers (N8): the driver installs and the controller overclock.</summary>
public sealed partial class ToolsTests
{
    [Fact]
    public void Restart_to_BIOS_restarts_into_the_firmware_or_says_why_not()
    {
        Assert.Equal(["firmware"], Lines(Blocks("tools-restart-to-bios"), "tools-restart-to-bios", "Apply"));
        Assert.Equal(OutcomeKind.Applied, Apply("tools-restart-to-bios").Kind);
        Assert.Equal(1, _h.Shutdown.FirmwareRestarts);

        var ps = Lines(Blocks("tools-restart-to-bios", "-FirmwareCode", "1"), "tools-restart-to-bios", "Apply");
        _h.Shutdown.FirmwareCode = 1;
        var o = Apply("tools-restart-to-bios");
        Assert.Equal((OutcomeKind.Failed, ps[^1][6..]), (o.Kind, o.Message));
        Assert.Contains("exit code 1", o.Message);
    }

    private const string NvidiaLookup = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=120&pfid=929&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1";
    private const string NvidiaAnswer = """{"Success":"1","IDS":[{"downloadInfo":{"Success":"1","ID":"237922","Version":"566.36","Name":"GeForce Game Ready Driver"}}]}""";

    private void Nvidia()
    {
        _h.Pc.Gpus = [new Gpu(@"HKLM:\x", "GeForce", "NVIDIA")];
        _h.Http.Pages[NvidiaLookup] = NvidiaAnswer;
    }

    [Fact]
    public void The_latest_NVIDIA_driver_is_looked_up_downloaded_and_started()
    {
        Nvidia();
        var ps = Lines(Blocks("tools-driver-nvidia", "-WebContent", NvidiaAnswer), "tools-driver-nvidia", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-driver-nvidia").Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Contains(@"web https://international.download.nvidia.com/Windows/566.36/566.36-desktop-win10-win11-64bit-international-dch-whql.exe|%SystemRoot%\Temp\nvidiadriver.exe", CsDid());
        AssertLogged(ps);

        // no version in the answer
        _h.Http.Pages[NvidiaLookup] = "{}";
        ps = Lines(Blocks("tools-driver-nvidia", "-WebContent", "{}"), "tools-driver-nvidia", "Apply");
        var o = Apply("tools-driver-nvidia");
        Assert.Equal((OutcomeKind.Failed, ps[^1][6..]), (o.Kind, o.Message));
    }

    private const string AmdPage = "https://www.amd.com/en/support/download/drivers.html";
    private const string AmdSetup = "https://drivers.amd.com/drivers/installer/24.30/whql/amd-software-adrenalin-edition-24.12.1-minimalsetup-241204_web.exe";

    [Fact]
    public void The_AMD_setup_link_is_read_off_AMDs_page_as_a_browser()
    {
        _h.Pc.Gpus = [new Gpu(@"HKLM:\x", "Radeon", "AMD")];
        string[] links = ["https://www.amd.com/en/support.html", "https://drivers.amd.com/drivers/amd-software-adrenalin-edition-24.12.1-win10-win11-dec-rdna.exe", AmdSetup, AmdSetup.Replace("24.12.1", "24.10.1")];
        _h.Http.Pages[AmdPage] = "<html><body>" + string.Concat(links.Select(l => $"<p><a class=\"btn\" href=\"{l}\">Download</a></p>\n")) + "</body></html>";
        var ps = Lines(Blocks("tools-driver-amd", "-WebLinks", string.Join(';', links)), "tools-driver-amd", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-driver-amd").Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Contains($@"web {AmdSetup}|%SystemRoot%\Temp\amddriver.exe +headers", CsDid());
        Assert.All(_h.Http.Headers, h => Assert.Equal(
            ["Accept=text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", "Referer=https://www.amd.com/",
             "User-Agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"],
            h.Select(kv => $"{kv.Key}={kv.Value}").Order(StringComparer.Ordinal)));

        // the page changed
        _h.Http.Pages[AmdPage] = "<html></html>";
        ps = Lines(Blocks("tools-driver-amd"), "tools-driver-amd", "Apply");
        var o = Apply("tools-driver-amd");
        Assert.Equal((OutcomeKind.Failed, ps[^1][6..]), (o.Kind, o.Message));
    }

    /// <summary>A driver package's folder as 7-Zip unpacks it (both sides' fake 7-Zip copies it); the C# fake also keeps
    /// what each installer found in the unpacked folder (the PowerShell side's "snap" lines).</summary>
    private (string Folder, List<string> Snaps) Package(string snapshot, params string[] files)
    {
        var folder = _h.Folder("package");
        foreach (var (name, text) in files.Select(f => (f.Split('=', 2)[0], f.Split('=', 2).ElementAtOrDefault(1) ?? "")))
        {
            var p = Path.Combine(folder, name);
            Directory.CreateDirectory(Path.GetDirectoryName(p)!);
            File.WriteAllText(p, text);
        }
        Files(@"%ProgramFiles%\7-Zip\7z.exe");
        var snaps = new List<string>();
        _h.Exe.Result = (path, args) =>
        {
            if (Path.GetFileName(path) == "7z.exe" && args.StartsWith("x ", StringComparison.Ordinal))
            {
                var to = Regex.Match(args, "\"?-o([^\"\\s]+)").Groups[1].Value;
                foreach (var f in Directory.EnumerateFiles(folder, "*", SearchOption.AllDirectories))
                {
                    var target = Path.Combine(to, Path.GetRelativePath(folder, f));
                    Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                    File.Copy(f, target, overwrite: true);
                }
            }
            // msiexec: the PowerShell side starts it through Start-Process, not Invoke-AkariExe
            else if (Path.GetFileName(path) != "msiexec.exe")
            {
                var snap = snapshot.Replace("%SystemRoot%", _cs.Windows).Replace("%SystemDrive%", _h.Engine.Services.SystemDrive.TrimEnd('\\'));
                if (Directory.Exists(snap))
                    snaps.AddRange(Directory.EnumerateFiles(snap, "*", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase)
                        .Select(f => $"snap {Drive(_cs.Vars(f), _h.Engine.Services.SystemDrive)}|{File.ReadAllText(f)}"));
            }
            return new(0, "");
        };
        return (folder, snaps);
    }

    private static string Drive(string text, string drive) => text.Replace(drive.TrimEnd('\\'), "%SystemDrive%", StringComparison.OrdinalIgnoreCase);

    private string[] DriverArgs(string snapshot, string unpack, string psDrive) =>
        ["-Unpack", unpack, "-Snapshot", snapshot.Replace("%SystemRoot%", _ps.Windows).Replace("%SystemDrive%", psDrive), "-SystemDrive", psDrive];

    /// <summary>A file in each side's user Downloads (= the user folder here), with its last write time.</summary>
    private void Download(string name, DateTime written)
    {
        foreach (var r in new[] { _cs, _ps })
        {
            var p = Path.Combine(r.User, name);
            File.WriteAllText(p, "");
            File.SetLastWriteTimeUtc(p, written);
        }
    }

    [Fact]
    public void The_NVIDIA_driver_is_installed_stripped()
    {
        Nvidia();
        var psDrive = _h.Folder("ps-C");
        foreach (var d in new[] { _h.Engine.Services.SystemDrive, psDrive }) Directory.CreateDirectory(Path.Combine(d, @"NVIDIA\DisplayDriver"));
        var (pkg, snaps) = Package(@"%SystemRoot%\Temp\nvidiadriver", "setup.exe", "setup.cfg=<setup/>", @"Display.Driver\nv.inf", @"HDAudio\a.inf", @"PhysX\p.msi",
            @"NvApp\CEF\c.dll", @"NvApp\7z.exe", @"NvApp\Keep.dll", @"NvTelemetry\t.dll");
        var ps = Lines(Blocks("tools-driver-nvidia-debloat", ["-WebContent", NvidiaAnswer, .. DriverArgs(@"%SystemRoot%\Temp\nvidiadriver", pkg, psDrive)]),
            "tools-driver-nvidia-debloat", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-driver-nvidia-debloat").Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Contains(@"run %SystemRoot%\Temp\nvidiadriver\setup.exe|-s -noreboot -noeula -clean", CsDid());
        Assert.Contains(@"appx %SystemRoot%\Temp\nvp.appx", CsDid());
        // what setup.exe found: the stripped package
        Assert.Equal(Of(ps, "snap"), snaps);
        Assert.DoesNotContain(snaps, s => s.Contains(@"\HDAudio\", StringComparison.Ordinal) || s.Contains(@"\NvApp\CEF\", StringComparison.Ordinal));
        Assert.Contains(snaps, s => s.Contains(@"\NvApp\Keep.dll", StringComparison.Ordinal));
        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.False(Directory.Exists(Path.Combine(_h.Engine.Services.SystemDrive, "NVIDIA")));
        Assert.False(Directory.Exists(Path.Combine(psDrive, "NVIDIA")));
        AssertLogged(ps);
    }

    private const string AmdPackage = "amd-software-adrenalin-edition-24.12.1-win10-win11-dec5-rdna.exe";

    [Fact]
    public void The_AMD_driver_is_installed_from_Downloads_with_its_extras_off()
    {
        _h.Pc.Gpus = [new Gpu(@"HKLM:\x", "Radeon", "AMD")];
        var psDrive = _h.Folder("ps-C");
        Download("amd-software-adrenalin-edition-24.10.1-win10-win11-oct-rdna.exe", new DateTime(2024, 10, 1));
        Download(AmdPackage, new DateTime(2024, 12, 5));
        Download("amd-software-adrenalin-edition-25.1.1-minimalsetup-250115_web.exe", new DateTime(2025, 1, 15));
        foreach (var d in new[] { _h.Engine.Services.SystemDrive, psDrive }) Directory.CreateDirectory(Path.Combine(d, @"AMD\Chipset"));
        Files(@"%SystemRoot%\SysWOW64\AMDBugReportTool.exe", @"%ProgramData%\Microsoft\Windows\Start Menu\Programs\AMD Bug Report Tool\Bug.lnk");
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "AMDNoiseSuppression", "x.exe", "String");
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce", "StartRSX", "rsx.exe", "String");
        _h.Set(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{AAAA-1}", "DisplayName", "AMD Install Manager", "String");
        _h.Tasks.All[new ScheduledTask(@"\", "StartCN")] = true;
        var (pkg, snaps) = Package(@"%SystemRoot%\Temp\amddriver", @"Bin64\ATISetup.exe",
            @"Config\AMDUpdater.xml=<Component><Enabled>true</Enabled><Hidden>true</Hidden></Component>",
            @"Config\InstallUEP.xml=<Component><Enabled>true</Enabled></Component>", @"Config\Other.xml=<Enabled>true</Enabled>",
            @"Config\InstallManifest.json={ ""Packages"": [ { ""InstallByDefault"" : ""Yes"" }, { ""InstallByDefault"":""Yes"" } ] }",
            @"Bin64\cccmanifest_64.json={""InstallByDefault"": ""Yes""}");
        var ps = Lines(Blocks("tools-driver-amd-debloat", ["-Tasks", @"\|StartCN", .. DriverArgs(@"%SystemRoot%\Temp\amddriver", pkg, psDrive)]),
            "tools-driver-amd-debloat", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-driver-amd-debloat").Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Contains(@"run %SystemRoot%\Temp\amddriver\Bin64\ATISetup.exe|-INSTALL -VIEW:2", CsDid());
        Assert.Contains(CsDid(), l => l.Contains(AmdPackage, StringComparison.Ordinal));
        Assert.Equal(Of(ps, "snap"), snaps);
        Assert.Contains(snaps, s => s.EndsWith(@"AMDUpdater.xml|<Component><Enabled>false</Enabled><Hidden>false</Hidden></Component>", StringComparison.Ordinal));
        // the services: stopped, then deleted, in the block's order
        Assert.Equal(Of(ps, "stopservice", "delservice").Select(l => l.Replace("stopservice ", "stop ").Replace("delservice ", "delete ")), _h.Services.Calls);
        Assert.Equal([@"unregister \|StartCN"], Of(ps, "unregister"));
        Assert.Empty(_h.Tasks.All);
        Assert.Null(_h.Get(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "AMDNoiseSuppression"));
        Assert.Null(_h.Get(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce", "StartRSX"));
        Assert.Contains(_h.Exe.Runs, r => r == "msiexec.exe /x {AAAA-1} /qn /norestart");
        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.DoesNotContain($@"%User%\{AmdPackage}", _cs.Tree());
        Assert.False(Directory.Exists(Path.Combine(_h.Engine.Services.SystemDrive, "AMD")));
        AssertLogged(ps);
    }

    [Fact]
    public void A_debloated_driver_needs_its_package_in_Downloads()
    {
        _h.Pc.Gpus = [new Gpu(@"HKLM:\x", "Arc", "Intel")];
        var ps = Lines(Blocks("tools-driver-intel-debloat"), "tools-driver-intel-debloat", "Apply");
        var o = Apply("tools-driver-intel-debloat");
        Assert.Equal((OutcomeKind.Failed, ps[^1][6..]), (o.Kind, o.Message));
        Assert.Equal(PsDid(ps), CsDid());
        Assert.StartsWith("open https://www.intel.com/", CsDid().Single());
    }

    [Fact]
    public void The_Intel_driver_is_installed_from_Downloads_without_extras()
    {
        _h.Pc.Gpus = [new Gpu(@"HKLM:\x", "Arc", "Intel")];
        var psDrive = _h.Folder("ps-C");
        Download("gfx_win_101.6083.exe", new DateTime(2024, 9, 1));
        Download("gfx_win_101.6314.exe", new DateTime(2024, 12, 1));
        _h.Set(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "Intel® Graphics Software", "igs.exe", "String");
        var (pkg, snaps) = Package(@"%SystemDrive%\inteldriver", "Installer.exe", @"Resources\Extras\IntelGraphicsSoftware_25.1.exe", @"Resources\Extras\Other.exe");
        var ps = Lines(Blocks("tools-driver-intel-debloat", DriverArgs(@"%SystemDrive%\inteldriver", pkg, psDrive)), "tools-driver-intel-debloat", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-driver-intel-debloat").Kind);
        // the unpacked folder is on the system drive: each side's own
        Assert.Equal(PsDid(ps).Select(l => Drive(l, psDrive)), CsDid().Select(l => Drive(l, _h.Engine.Services.SystemDrive)));
        Assert.Contains(CsDid().Select(l => Drive(l, _h.Engine.Services.SystemDrive)), l => l == @"run %SystemDrive%\inteldriver\Installer.exe|-f --noExtras --terminateProcesses -s");
        Assert.Contains(CsDid(), l => l.Contains("gfx_win_101.6314.exe", StringComparison.Ordinal));
        Assert.Equal(Of(ps, "snap").Select(l => Drive(l, psDrive)), snaps);
        Assert.Null(_h.Get(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "Intel® Graphics Software"));
        Assert.Equal(Of(ps, "stop").Select(l => l[5..]), _h.Processes.Stopped);
        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.False(Directory.Exists(Path.Combine(_h.Engine.Services.SystemDrive, "inteldriver")));
        AssertLogged(ps);
    }

    [Fact]
    public void Hidusbf_is_unpacked_installed_and_its_Setup_opened()
    {
        var zip = Path.Combine(_h.Folder("zip"), "hidusbf.zip");
        using (var z = ZipFile.Open(zip, ZipArchiveMode.Create))
            foreach (var f in new[] { @"hidusbf (BB11.5.25)/DRIVER/Setup.exe", @"hidusbf (BB11.5.25)/DRIVER/HIDUSBF_AS.INF", @"hidusbf (BB11.5.25)/README.TXT" })
                using (var w = new StreamWriter(z.CreateEntry(f).Open())) w.Write(f);
        _h.Downloads.Files["hidusbf.zip"] = zip;
        var ps = Lines(Blocks("tools-controller-overclock", "-Downloaded", $"hidusbf.zip={zip}"), "tools-controller-overclock", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-controller-overclock").Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Contains(@"run %SystemRoot%\System32\rundll32.exe|setupapi.dll,InstallHinfSection DefaultInstall 132 %ProgramFiles(x86)%\hidusbf\DRIVER\HIDUSBF_AS.INF",
            CsDid());
        Assert.Contains(@"start %ProgramFiles(x86)%\hidusbf\DRIVER\Setup.exe|", CsDid());
        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.Equal(_ps.Contents(), _cs.Contents());
        Assert.Contains(@"%ProgramFiles(x86)%\hidusbf\README.TXT", _cs.Tree());
    }
}
