using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Tests.Apps;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Tools;

/// <summary>
/// Section Tools (N8) against their PowerShell blocks (Oracle/Invoke-TweakBlocks.ps1, -Logs): the same pages, programs,
/// downloads, console lines and files, each side in its own copy of the folders.
/// </summary>
public sealed partial class ToolsTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private readonly AppRoots _cs;
    private readonly AppRoots _ps;

    public ToolsTests()
    {
        var s = _h.Engine.Services;
        // the user's Local AppData two folders down, so LocalLow next to it stays inside each side's profile
        _cs = new AppRoots(s.Windows, s.ProgramFiles, s.ProgramFilesX86, s.ProgramData, s.Public, _h.Folder(@"User\AppData\Local"), s.LocalAppData);
        _ps = new AppRoots(_h.Folder("ps-Windows"), _h.Folder("ps-pf"), _h.Folder("ps-pf86"), _h.Folder("ps-data"), _h.Folder("ps-public"),
            _h.Folder(@"ps-user\AppData\Local"), _h.Folder("ps-local"));
        const string folders = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders";
        foreach (var n in new[] { "Local AppData", "{374DE290-123F-4565-9164-39C4925E467B}" }) _h.Set(folders, n, _cs.User, "String");
        // Windows' own Temp folder is always there
        foreach (var w in new[] { _cs.Windows, _ps.Windows }) Directory.CreateDirectory(Path.Combine(w, "Temp"));
    }

    public void Dispose() => _h.Dispose();

    private JsonElement Blocks(string ids, params string[] more) => Oracle.Run("Invoke-TweakBlocks.ps1",
    [
        "-Src", Repo.Src, "-Ids", ids, "-TestRoot", _h.KeyRoot, "-SystemRoot", _ps.Windows, "-ProgramFiles", _ps.ProgramFiles,
        "-ProgramFilesX86", _ps.X86, "-ProgramData", _ps.ProgramData, "-Public", _ps.Public, "-UserFolder", _ps.User, "-LocalAppData", _ps.LocalAppData,
        "-TestDir", _h.Dir, "-MakeFiles", "-Logs", .. more,
    ]);

    private Outcome Apply(string id) => _h.Run(id, TweakMode.Apply);

    /// <summary>The PowerShell console lines ("log …") were written by the C# side too, in order, one after the other.</summary>
    private void AssertLogged(IEnumerable<string> lines)
    {
        var ps = lines.Where(l => l.StartsWith("log ", StringComparison.Ordinal)).Select(l => _ps.Vars(l[4..])).ToList();
        var cs = _h.Log.Lines.Select(_cs.Vars).ToList();
        Assert.NotEmpty(ps);
        var at = cs.IndexOf(ps[0]);
        Assert.True(at >= 0, $"not logged: {ps[0]}");
        Assert.Equal(ps, cs.Skip(at).Take(ps.Count).ToList());
    }

    /// <summary>What C# started: "open &lt;uri&gt;" (the launcher) or "run &lt;program&gt;|&lt;args&gt;" (not waited for), as %Root%.</summary>
    private List<string> Started() =>
        _h.Launcher.Opened.Select(u => $"open {u}")
            .Concat(_h.Exe.Full.Select(f => f.Split('|')).Select(f => $"run {_cs.Vars(f[0])}|{_cs.Vars(f[1])}|{f[2]}"))
            .ToList();

    private void Files(params string[] files)
    {
        foreach (var f in files) { _cs.Add(f); _ps.Add(f); }
    }

    /// <summary>What the PowerShell block did that the C# fakes record, as comparable lines, sorted: "open &lt;uri&gt;",
    /// "start &lt;program&gt;|&lt;args&gt;" (not waited for), "run …" (waited for), "download", "shortcut", "web", "winget",
    /// "appx", "clipboard".</summary>
    private List<string> PsDid(IEnumerable<string> lines) => lines.Select(l =>
    {
        var (kind, rest) = (l.Split(' ', 2)[0], l.Split(' ', 2).ElementAtOrDefault(1) ?? "");
        return kind switch
        {
            // System32 tools the blocks name bare (C# runs them from System32): msiexec waited for, rundll32 too
            "run" or "exe" when rest.StartsWith("msiexec.exe|", StringComparison.Ordinal) || rest.StartsWith("rundll32.exe|", StringComparison.Ordinal) =>
                $@"run %SystemRoot%\System32\{_ps.Vars(rest)}",
            "open" when rest.StartsWith("https:", StringComparison.Ordinal) || rest.StartsWith("ms-settings:", StringComparison.Ordinal) => l,
            "open" => $"start {_ps.Vars(rest)}|",
            "run" => $"start {_ps.Vars(rest)}",
            "exe" => $"run {_ps.Vars(rest)}",
            "download" or "shortcut" or "web" or "webtext" or "winget" or "appx" => $"{kind} {_ps.Vars(rest)}",
            _ => null,
        };
    }).OfType<string>().Order(StringComparer.Ordinal).ToList();

    private List<string> CsDid() => _h.Launcher.Opened.Select(u => $"open {u}")
        // Invoke-AkariExe's lines join the arguments with spaces: the quotes ExeArgs adds (as 5.1 does) left out
        .Concat(_h.Exe.Full.Select(f => f.Split('|')).Select(f => $"{(f[2] == "True" ? "run" : "start")} {_cs.Vars(f[0])}|{_cs.Vars(f[1]).Replace("\"", "")}"))
        .Concat(_h.Downloads.Saved.Select(s => $"download {_cs.Vars(s)}"))
        .Concat(_h.Shortcuts.Made.Select(s => $"shortcut {Path.GetFileNameWithoutExtension(s.Key)}|{_cs.Vars(s.Value)}"))
        .Concat(_h.Http.Saved.Select(s => $"web {_cs.Vars(s)}"))
        .Concat(_h.Http.Read.Select(s => $"webtext {s}"))
        .Concat(_h.Winget.Installs)
        .Concat(_h.Appx.Calls.Select(_cs.Vars))
        .Order(StringComparer.Ordinal).ToList();

    [Fact]
    public void The_real_tool_parts_never_run_in_a_test()
    {
        Assert.Throws<InvalidOperationException>(() => new WevtutilExe());
        Assert.Throws<InvalidOperationException>(() => new CleanMgrExe());
        Assert.Throws<InvalidOperationException>(() => new PnpUtilExe());
        Assert.Throws<InvalidOperationException>(() => new Clipboard());
        Assert.Throws<InvalidOperationException>(() => new ShutdownExe());
        Assert.Throws<InvalidOperationException>(() => new WmiHardware());
    }

    [Theory]
    [InlineData("tools-autoruns", @"%ProgramFiles%\Sysinternals\Autoruns64.exe")]
    [InlineData("tools-furmark", @"%ProgramFiles%\Geeks3D\FurMark2_x64\FurMark_GUI.exe")]
    [InlineData("tools-gpu-check", @"%ProgramFiles(x86)%\GPU-Z\GPU-Z.exe")]
    [InlineData("tools-ram-check", @"%ProgramFiles%\CPUID\CPU-Z\cpuz.exe")]
    [InlineData("tools-occt", @"%LOCALAPPDATA%\Microsoft\WinGet\Packages\OCBase.OCCT.Personal_Microsoft.Winget.Source_8wekyb3d8bbwe\OCCTPersonal.exe")]
    [InlineData("tools-oosu10", @"%LOCALAPPDATA%\Microsoft\WinGet\Packages\OO-Software.ShutUp10_Microsoft.Winget.Source_8wekyb3d8bbwe\OOSU10.exe")]
    public void A_winget_tool_opens_where_it_is(string id, string exe)
    {
        // deeper than two folders down: not looked at
        Files(@"%ProgramFiles%\A\B\C\Autoruns64.exe", @"%ProgramFiles%\A\B\C\cpuz.exe", exe);
        var ps = Lines(Blocks(id), id, "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply(id).Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Equal($"start {exe}|", CsDid().Single());
    }

    [Theory]
    [InlineData("tools-ram-check", "CPUID.CPU-Z", "cpuz.exe")]
    [InlineData("tools-occt", "OCBase.OCCT.Personal", "OCCT*.exe")]
    public void A_missing_winget_tool_is_installed_first(string id, string package, string exe)
    {
        Files(@"%ProgramFiles%\A\B\C\cpuz.exe");
        // winget lays nothing down: both fail the same way
        var ps = Lines(Blocks(id), id, "Apply");
        var o = Apply(id);
        Assert.Equal($"throw {package} is installed, but {exe} was not found", ps[^1]);
        Assert.Equal((OutcomeKind.Failed, ps[^1][6..]), (o.Kind, o.Message));
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Equal($"winget {package} winget", CsDid().Single());

        // it does: the program starts
        _h.Winget.OnInstall = _ => _cs.Add(@"%ProgramFiles%\Tool\" + exe.Replace("*", "Personal"));
        Assert.Equal(OutcomeKind.Applied, Apply(id).Kind);
        Assert.Equal($@"%ProgramFiles%\Tool\{exe.Replace("*", "Personal")}", _cs.Vars(_h.Exe.Full.Single().Split('|')[0]));
    }

    [Theory]
    [InlineData("tools-controller-polling-test", @"%ProgramFiles(x86)%\Polling\Polling.exe")]
    [InlineData("tools-mouse-polling-test", @"%ProgramFiles(x86)%\Mouse Movement Recorder\Mouse Movement Recorder.exe")]
    public void A_polling_test_is_downloaded_once_and_opened(string id, string exe)
    {
        var ps = Lines(Blocks(id), id, "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply(id).Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Contains(CsDid(), l => l.StartsWith("download ", StringComparison.Ordinal));

        // there already: no download, the shortcut made again
        _ps.Add(exe);
        _h.Downloads.Saved.Clear(); _h.Exe.Full.Clear(); _h.Shortcuts.Made.Clear();
        ps = Lines(Blocks(id), id, "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply(id).Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.DoesNotContain(CsDid(), l => l.StartsWith("download ", StringComparison.Ordinal));
    }

    [Theory]
    [InlineData("tools-gaming-repair")]
    [InlineData("tools-reinstall-windows-10")]
    [InlineData("tools-reinstall-windows-11")]
    public void A_repair_or_setup_tool_is_downloaded_and_started(string id)
    {
        var ps = Lines(Blocks(id), id, "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply(id).Kind);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Equal(2, CsDid().Count);
    }

    /// <summary>The block's own last words ("said …") were logged by the C# side too.</summary>
    private void AssertSaid(List<string> ps)
    {
        var said = ps.Single(l => l.StartsWith("said ", StringComparison.Ordinal))[5..];
        Assert.Contains(said, _h.Log.Lines);
    }

    [Fact]
    public void Every_event_log_is_cleared()
    {
        _h.Wevtutil.Logs.AddRange(["Application", "", "Microsoft-Windows-Kernel-Power/Thermal-Operational", "System"]);
        var ps = Lines(Blocks("cleanup-event-logs", "-EventLogs", "Application;;Microsoft-Windows-Kernel-Power/Thermal-Operational;System"), "cleanup-event-logs", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-event-logs").Kind);
        Assert.Equal(Of(ps, "wevtutil"), _h.Wevtutil.Calls);
        Assert.Equal("said Cleared 3 event logs", ps[^1]);
        AssertSaid(ps);
    }

    private const string Caches = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches";

    [Fact]
    public void Disk_cleanup_runs_with_the_categories_this_Windows_has()
    {
        foreach (var k in new[] { "Update Cleanup", "Temporary Files", "Recycle Bin", "Device Driver Packages" }) _h.Set($@"{Caches}\{k}", "Autorun", 1, "DWord");
        var ps = Lines(Blocks("cleanup-disk-cleanup"), "cleanup-disk-cleanup", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-disk-cleanup").Kind);
        AssertWrites(_h, ps);
        Assert.Equal(3, Of(ps, "set").Count);
        Assert.Null(_h.Get($@"{Caches}\Recycle Bin", "StateFlags0069"));
        Assert.Equal(["cleanmgr 69"], Of(ps, "cleanmgr"));
        Assert.Equal([69], _h.CleanMgr.Runs);
        AssertSaid(ps);
    }

    [Fact]
    public void Disk_cleanup_with_no_category_fails()
    {
        var ps = Lines(Blocks("cleanup-disk-cleanup"), "cleanup-disk-cleanup", "Apply");
        var o = Apply("cleanup-disk-cleanup");
        Assert.Equal((OutcomeKind.Failed, ps.Single()[6..]), (o.Kind, o.Message));
        Assert.Empty(_h.CleanMgr.Runs);
    }

    private List<string> Tree(AppRoots r) => Directory.EnumerateFileSystemEntries(Path.GetDirectoryName(Path.GetDirectoryName(r.User))!, "*", SearchOption.AllDirectories)
        .Select(e => e[Path.GetDirectoryName(Path.GetDirectoryName(r.User))!.Length..]).Concat(r.Tree()).Order(StringComparer.OrdinalIgnoreCase).ToList();

    [Fact]
    public void The_NVIDIA_shader_caches_go()
    {
        _h.Pc.Gpus = [new Gpu(@"HKLM:\x", "GeForce", "NVIDIA")];
        foreach (var r in new[] { _cs, _ps })
            foreach (var f in new[] { @"NVIDIA\GLCache\a\b.bin", @"..\LocalLow\NVIDIA\PerDriverVersion\DXCache\c.bin", @"..\LocalLow\NVIDIA\keep.txt" })
            {
                var p = Path.GetFullPath(Path.Combine(r.User, f));
                Directory.CreateDirectory(Path.GetDirectoryName(p)!);
                File.WriteAllText(p, "");
            }
        var ps = Lines(Blocks("cleanup-nvidia-shader-cache"), "cleanup-nvidia-shader-cache", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-nvidia-shader-cache").Kind);
        Assert.Contains("said Deleted 2 shader caches", ps);
        AssertSaid(ps);
        Assert.Equal(Tree(_ps), Tree(_cs));
        Assert.Contains(@"\AppData\LocalLow\NVIDIA\keep.txt", Tree(_cs));
    }

    [Fact]
    public void The_temp_folders_are_emptied()
    {
        Files(@"%SystemRoot%\Temp\a.tmp", @"%SystemRoot%\Temp\Sub\b.tmp", @"%User%\Temp\c.tmp", @"%User%\Temp\D\e.tmp", @"%User%\Other\f.txt");
        var ps = Lines(Blocks("cleanup-temp-files"), "cleanup-temp-files", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-temp-files").Kind);
        Assert.Contains("said Deleted 4 temporary files and folders", ps);
        AssertSaid(ps);
        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.Contains(@"%User%\Other\f.txt", _cs.Tree());
    }

    [Fact]
    public void Windows_log_files_go_the_Update_Medic_ones_taken_over_first()
    {
        Files(@"%SystemRoot%\setupact.log", @"%SystemRoot%\Panther\setup.etl", @"%SystemRoot%\Panther\UnattendGC\x.log", @"%SystemRoot%\Logs\CBS\CBS.log",
            @"%SystemRoot%\Logs\CBS\CbsPersist.log", @"%SystemRoot%\Logs\waasmedic\w.etl", @"%SystemRoot%\System32\catroot2.edb", @"%SystemRoot%\System32\kept.dll",
            @"%SystemRoot%\Traces\WindowsUpdate\t.etl", @"%User%\Microsoft\CLR_v4.0\UsageTraces\app.log");
        var ps = Lines(Blocks("cleanup-windows-logs"), "cleanup-windows-logs", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-windows-logs").Kind);
        Assert.Equal(@"own %SystemRoot%\Logs\waasmedic", ps[0]);
        Assert.Equal([@"takeown.exe /f ""%SystemRoot%\Logs\waasmedic"" /a /r /d y", @"icacls.exe ""%SystemRoot%\Logs\waasmedic"" /grant *S-1-5-32-544:F /t /q"],
            _h.Exe.Runs.Select(_cs.Vars));
        Assert.Contains("said Deleted 8 log files and folders", ps);
        AssertSaid(ps);
        Assert.Equal(_ps.Tree(), _cs.Tree());
    }

    [Fact]
    public void Windows_old_goes_as_TrustedInstaller_then_as_the_administrators()
    {
        var csDrive = _h.Engine.Services.SystemDrive;
        var psDrive = _h.Folder("ps-C");
        var args = new[] { "-SystemDrive", psDrive };
        Assert.Equal("said There is no Windows.old folder", Lines(Blocks("cleanup-windows-old", args), "cleanup-windows-old", "Apply").Single());
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-windows-old").Kind);
        Assert.Contains("There is no Windows.old folder", _h.Log.Lines);
        Assert.Empty(_h.Trusted.Started);

        foreach (var d in new[] { csDrive, psDrive }) { Directory.CreateDirectory(Path.Combine(d, @"Windows.old\Windows\System32")); File.WriteAllText(Path.Combine(d, @"Windows.old\Windows\System32\a.dll"), ""); }
        var ps = Lines(Blocks("cleanup-windows-old", args), "cleanup-windows-old", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-windows-old").Kind);
        Assert.Equal(@"trustedrun Remove-Item -LiteralPath '%SystemDrive%\Windows.old' -Recurse -Force -ErrorAction SilentlyContinue", ps[0]);
        Assert.Equal([$@"{csDrive}\Windows.old"], _h.Trusted.Started.Select(s => s.Split('|')[1]).Select(a => a.Split('"')[1].Replace(@"\\", @"\")));
        Assert.Equal(@"own %SystemDrive%\Windows.old", ps[1]);
        Assert.Contains(_h.Exe.Runs, r => r.StartsWith("takeown.exe", StringComparison.Ordinal));
        Assert.Equal("said Windows.old deleted", ps[^1]);
        AssertSaid(ps);
        Assert.False(Directory.Exists(Path.Combine(csDrive, "Windows.old")));
        Assert.False(Directory.Exists(Path.Combine(psDrive, "Windows.old")));
    }

    [Fact]
    public void Old_duplicate_drivers_go_the_newest_of_each_kept()
    {
        const string drivers = @"oem10.inf|C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_a\nv_dispi.inf|NVIDIA|Display|31.0.15.5222|2024-03-01;" +
            @"oem12.inf|C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_b\nv_dispi.inf|NVIDIA|Display|32.0.15.6094|2024-08-14;" +
            @"oem3.inf|C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_c\nv_dispi.inf|nvidia|Display|31.0.15.3742|2023-09-12;" +
            @"oem5.inf|C:\x\rt640x64.inf|Realtek|Net|10.68.815.2023|2023-08-15;" +
            @"oem7.inf|C:\y\rt640x64.inf|Realtek|Net|garbage|2024-01-01;" +
            @"oem8.inf|C:\z\only.inf|Vendor|System|1.0.0.0|2020-01-01";
        foreach (var d in drivers.Split(';'))
        {
            var p = d.Split('|');
            _h.Drivers.Packages.Add(new(p[0], p[1], p[2], p[3], p[4], DateTime.ParseExact(p[5], "yyyy-MM-dd", null)));
        }
        _h.Drivers.Kept.Add("oem10.inf");
        var ps = Lines(Blocks("cleanup-old-drivers", "-Drivers", drivers, "-DriversKept", "oem10.inf"), "cleanup-old-drivers", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("cleanup-old-drivers").Kind);
        // newest by version (an unreadable version counts as 0.0), the provider's case aside
        Assert.Equal(["pnputil oem10.inf", "pnputil oem3.inf", "pnputil oem7.inf"], Of(ps, "pnputil"));
        Assert.Equal(Of(ps, "pnputil"), _h.Drivers.Calls);
        Assert.Equal("said Deleted 2 of 3 old driver packages", ps[^1]);
        AssertSaid(ps);
    }

    [Theory]
    [InlineData("tools-bufferbloat-test", "open https://www.waveform.com/tools/bufferbloat", "open https://www.waveform.com/tools/bufferbloat")]
    [InlineData("tools-installed-programs", "open appwiz.cpl", @"run %SystemRoot%\System32\control.exe|appwiz.cpl|False")]
    [InlineData("tools-optional-features", "open ms-settings:optionalfeatures", "open ms-settings:optionalfeatures")]
    [InlineData("tools-windows-features", "open optionalfeatures.exe", @"run %SystemRoot%\System32\optionalfeatures.exe||False")]
    [InlineData("tools-factory-reset", "open ms-settings:recovery", "open ms-settings:recovery")]
    [InlineData("tools-local-account", "open netplwiz.exe", @"run %SystemRoot%\System32\netplwiz.exe||False")]
    [InlineData("tools-activation", "open ms-settings:activation", "open ms-settings:activation")]
    // winutil's Legacy Windows panels (Tools/Panels)
    [InlineData("tools-panel-computer-management", "open compmgmt.msc", @"run %SystemRoot%\System32\mmc.exe|compmgmt.msc|False")]
    [InlineData("tools-panel-control", "open control.exe", @"run %SystemRoot%\System32\control.exe||False")]
    [InlineData("tools-panel-network", "open ncpa.cpl", @"run %SystemRoot%\System32\control.exe|ncpa.cpl|False")]
    [InlineData("tools-panel-power", "open powercfg.cpl", @"run %SystemRoot%\System32\control.exe|powercfg.cpl|False")]
    [InlineData("tools-panel-printers", "run explorer.exe|shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}", @"run %SystemRoot%\explorer.exe|shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}|False")]
    [InlineData("tools-panel-region", "open intl.cpl", @"run %SystemRoot%\System32\control.exe|intl.cpl|False")]
    [InlineData("tools-panel-security", "open wscui.cpl", @"run %SystemRoot%\System32\control.exe|wscui.cpl|False")]
    [InlineData("tools-panel-system", "open sysdm.cpl", @"run %SystemRoot%\System32\control.exe|sysdm.cpl|False")]
    [InlineData("tools-panel-date-time", "open timedate.cpl", @"run %SystemRoot%\System32\control.exe|timedate.cpl|False")]
    [InlineData("tools-panel-firewall", "open firewall.cpl", @"run %SystemRoot%\System32\control.exe|firewall.cpl|False")]
    [InlineData("tools-driver-intel",
        "open https://www.intel.com/content/www/us/en/search.html#sortCriteria=%40lastmodifieddt%20descending&f-operatingsystem_en=Windows%2011%20Family*&f-downloadtype=Drivers&cf-tabfilter=Downloads",
        "open https://www.intel.com/content/www/us/en/search.html#sortCriteria=%40lastmodifieddt%20descending&f-operatingsystem_en=Windows%2011%20Family*&f-downloadtype=Drivers&cf-tabfilter=Downloads")]
    public void A_page_or_window_opens(string id, string ps, string cs)
    {
        _h.Pc.Gpus = [new Gpu(@"HKLM:\x", "Intel Arc", "Intel")];
        Assert.Equal([ps], Lines(Blocks(id), id, "Apply"));
        Assert.Equal(OutcomeKind.Applied, Apply(id).Kind);
        Assert.Equal([cs], Started());
    }

    [Fact]
    public void The_monitor_test_lists_what_to_change_and_opens_TestUFO()
    {
        var ps = Lines(Blocks("tools-monitor-test"), "tools-monitor-test", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-monitor-test").Kind);
        AssertLogged(ps);
        Assert.Equal(["open https://www.testufo.com/framerates#count=6&background=none&pps=1920"], Started());
        Assert.Equal(Started(), ps.Where(l => !l.StartsWith("log ", StringComparison.Ordinal)));
    }

    [Theory]
    [InlineData("3024|2024-08-05")]
    [InlineData("1.2.3|")]
    public void The_BIOS_check_names_the_board_and_searches_for_its_BIOS(string bios)
    {
        var (version, date) = (bios.Split('|')[0], bios.Split('|')[1]);
        _h.Hardware.BiosIs = new BiosInfo(version, date.Length > 0 ? DateTime.Parse(date, System.Globalization.CultureInfo.InvariantCulture) : null);
        var ps = Lines(Blocks("tools-bios-check", "-Board", "ASUSTeK COMPUTER INC.|ROG STRIX B650E-F GAMING WIFI", "-Bios", bios), "tools-bios-check", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-bios-check").Kind);
        AssertLogged(ps);
        Assert.Equal(ps.Where(l => !l.StartsWith("log ", StringComparison.Ordinal)), Started());
        Assert.StartsWith("open https://www.google.com/search?q=ASUSTeK%20COMPUTER%20INC.%20ROG", Started().Single());
    }

    [Fact]
    public void The_network_driver_search_names_the_board()
    {
        var ps = Lines(Blocks("tools-network-driver", "-Board", "Micro-Star International Co., Ltd.|MAG B550 TOMAHAWK (MS-7C91)"), "tools-network-driver", "Apply");
        _h.Hardware.BoardIs = new BoardInfo("Micro-Star International Co., Ltd.", "MAG B550 TOMAHAWK (MS-7C91)");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-network-driver").Kind);
        AssertLogged(ps);
        Assert.Equal(ps.Where(l => !l.StartsWith("log ", StringComparison.Ordinal)), Started());
    }

    [Fact]
    public void The_storage_check_shows_each_drive_and_opens_This_PC()
    {
        _h.Hardware.All.AddRange([new VolumeInfo('C', 999_653_638_144, 412_316_860_416), new VolumeInfo('D', 2_000_396_288_000, 150_000_000_000)]);
        var ps = Lines(Blocks("tools-storage-check", "-Volumes", "C|999653638144|412316860416;D|2000396288000|150000000000"), "tools-storage-check", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-storage-check").Kind);
        AssertLogged(ps);
        Assert.Contains("C: 41% free (384 of 931 GB)", _h.Log.Lines);
        Assert.Equal(@"run explorer.exe|shell:MyComputerFolder", ps[^1]);
        Assert.Equal([@"run %SystemRoot%\explorer.exe|shell:MyComputerFolder|False"], Started());
    }

    [Fact]
    public void Home_to_Pro_copies_the_generic_key_and_opens_Change_product_key()
    {
        _h.Pc.Edition = "Core";
        var ps = Lines(Blocks("tools-home-to-pro"), "tools-home-to-pro", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-home-to-pro").Kind);
        AssertLogged(ps);
        Assert.Equal([ps.Single(l => l.StartsWith("clipboard ", StringComparison.Ordinal))[10..]], _h.Clipboard.Texts);
        Assert.Equal(_ps.Vars(ps[^1]) + "|False", Started().Single());
    }
}
