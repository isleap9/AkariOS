using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Tests.Apps;
using Microsoft.Win32;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.OneClick;

/// <summary>
/// One-click's own steps and the two Tools Actions the AkariOS preset runs (N7) against their PowerShell blocks
/// (Oracle/Invoke-TweakBlocks.ps1): the same programs, downloads, registry writes and restore points, and the same
/// files left in each side's own copy of the folders.
/// </summary>
public sealed class OneClickTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private readonly AppRoots _cs;
    private readonly AppRoots _ps;

    public OneClickTests()
    {
        var s = _h.Engine.Services;
        _cs = new AppRoots(s.Windows, s.ProgramFiles, s.ProgramFilesX86, s.ProgramData, s.Public, _h.Folder("User"), s.LocalAppData);
        _ps = new AppRoots(_h.Folder("ps-Windows"), _h.Folder("ps-pf"), _h.Folder("ps-pf86"), _h.Folder("ps-data"), _h.Folder("ps-public"), _h.Folder("ps-user"), _h.Folder("ps-local"));
        const string folders = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders";
        _h.Set(folders, "AppData", _cs.User, "String");
    }

    public void Dispose()
    {
        // DDU's settings file is left read only, as the blocks leave it
        foreach (var f in Directory.EnumerateFiles(_h.Dir, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
        _h.Dispose();
    }

    private void Files(params string[] files)
    {
        foreach (var f in files) { _cs.Add(f); _ps.Add(f); }
    }

    private JsonElement Blocks(string ids, params string[] more) => Oracle.Run("Invoke-TweakBlocks.ps1",
    [
        "-Src", Repo.Src, "-Ids", ids, "-TestRoot", _h.KeyRoot, "-SystemRoot", _ps.Windows, "-ProgramFiles", _ps.ProgramFiles,
        "-ProgramFilesX86", _ps.X86, "-ProgramData", _ps.ProgramData, "-Public", _ps.Public, "-UserFolder", _ps.User, "-LocalAppData", _ps.LocalAppData,
        "-MakeFiles", .. more,
    ]);

    /// <summary>What the PowerShell block did that the C# fakes record, as comparable lines (paths as %Root%).</summary>
    private List<string> PsDid(IEnumerable<string> lines) => lines.Select(l =>
    {
        var (kind, rest) = (l.Split(' ', 2)[0], l.Split(' ', 2).ElementAtOrDefault(1) ?? "");
        return kind switch
        {
            "run" => $"run {_ps.Vars(rest)}",
            "open" => $"run {_ps.Vars(rest)}|",
            "exe" => $"run {_ps.Vars(rest)}",
            "download" or "winget" or "restorepoint" or "readonly" => $"{kind} {_ps.Vars(rest)}",
            _ => null,
        };
    }).OfType<string>().Order(StringComparer.Ordinal).ToList();

    private List<string> CsDid() => _h.Exe.Full.Select(f => f.Split('|')).Select(f => $"run {_cs.Vars(f[0])}|{_cs.Vars(f[1])}")
        .Concat(_h.Downloads.Saved.Select(s => $"download {_cs.Vars(s)}"))
        .Concat(_h.Restore.Made.Select(d => $"restorepoint {d}"))
        .Order(StringComparer.Ordinal).ToList();

    private Outcome Apply(string id) => _h.Run(id, TweakMode.Apply);

    [Fact]
    public void Scripts_run_on_double_click()
    {
        var ps = Blocks("oneclick-allow-scripts");
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-allow-scripts").Kind);
        // the program path in the value is each side's %SystemRoot%
        var cs = _h.Get(@"HKLM:\SOFTWARE\Classes\Applications\powershell.exe\shell\open\command", "(default)") as string;
        Assert.Equal(_ps.Vars(Lines(ps, "oneclick-allow-scripts", "Apply")[0].Split('|')[2]), _cs.Vars(cs!));
        AssertWrites(_h, Lines(ps, "oneclick-allow-scripts", "Apply").Skip(1).ToList());
    }

    [Fact]
    public void Performance_counters_are_rebuilt_where_lodctr_is()
    {
        Files(@"%SystemRoot%\System32\lodctr.exe");
        var ps = Blocks("oneclick-performance-counters");
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-performance-counters").Kind);
        Assert.Equal(PsDid(Lines(ps, "oneclick-performance-counters", "Apply")), CsDid());
        Assert.Single(CsDid());
    }

    [Fact]
    public void A_restore_point_of_the_finished_setup()
    {
        var ps = Blocks("oneclick-restore-point");
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-restore-point").Kind);
        Assert.Equal(PsDid(Lines(ps, "oneclick-restore-point", "Apply")), CsDid());

        // refused: the Action fails (the PowerShell block throws the message)
        ps = Blocks("oneclick-restore-point", "-RestoreFails");
        Assert.StartsWith("throw ", Lines(ps, "oneclick-restore-point", "Apply")[^1]);
        _h.Restore.Refuse = true;
        Assert.Equal(OutcomeKind.Failed, Apply("oneclick-restore-point").Kind);
    }

    [Fact]
    public void DDU_is_unpacked_with_its_settings_read_only()
    {
        Files(@"%ProgramFiles%\7-Zip\7z.exe");
        var ps = Blocks("oneclick-ddu-prepare");
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-ddu-prepare").Kind);
        var lines = Lines(ps, "oneclick-ddu-prepare", "Apply");
        Assert.Equal(PsDid(lines.Where(l => !l.StartsWith("readonly", StringComparison.Ordinal))), CsDid());
        Assert.Contains($@"readonly %SystemRoot%\Temp\ddu\Settings\Settings.xml|True", lines);
        Assert.True(File.GetAttributes(Path.Combine(_cs.Windows, @"Temp\ddu\Settings\Settings.xml")).HasFlag(FileAttributes.ReadOnly));
        Assert.Equal(_ps.Contents(), _cs.Contents());
        Assert.Equal(_ps.Tree(), _cs.Tree());

        // again: the read-only settings file is replaced all the same
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-ddu-prepare").Kind);
    }

    [Fact]
    public void DDU_needs_7_zip()
    {
        var ps = Blocks("oneclick-ddu-prepare");
        Assert.Equal("throw 7-Zip is not installed (install-7-zip)", Lines(ps, "oneclick-ddu-prepare", "Apply")[^1]);
        var o = Apply("oneclick-ddu-prepare");
        Assert.Equal((OutcomeKind.Failed, "7-Zip is not installed (install-7-zip)"), (o.Kind, o.Message));
    }

    [Fact]
    public void DDU_cleans_the_drivers_and_restarts_or_says_it_is_not_ready()
    {
        var ps = Blocks("oneclick-ddu-clean");
        var said = Lines(ps, "oneclick-ddu-clean", "Apply").Single();
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-ddu-clean").Kind);
        Assert.Empty(CsDid());
        Assert.Contains(said[5..], _h.Log.Lines);

        Files(@"%SystemRoot%\Temp\ddu\Display Driver Uninstaller.exe");
        ps = Blocks("oneclick-ddu-clean");
        Apply("oneclick-ddu-clean");
        Assert.Equal(PsDid(Lines(ps, "oneclick-ddu-clean", "Apply")), CsDid());
        // its own window, waited for (DDU restarts the PC itself)
        Assert.EndsWith("|True|False", _h.Exe.Full.Single());
    }

    [Fact]
    public void Reg_reg_is_written_as_reg_exe_imports_it()
    {
        var ps = Blocks("oneclick-registry");
        var text = RegReader.Decode(File.ReadAllBytes(Path.Combine(Repo.Src, "OneClick", "reg.reg")));
        Assert.Equal(Norm(text), Norm(Lines(ps, "oneclick-registry", "Apply").Single()["regimport ".Length..]));

        // a key reg.reg deletes, with something in it
        _h.Set(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}", "x", 1, "DWord");
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-registry").Kind);

        // the file read in order: what holds at the end
        var values = new Dictionary<(string Path, string Name), RegFileValue?>();
        var deleted = new List<string>();
        foreach (var k in RegReader.Parse(text).Keys)
        {
            var path = RegReader.ToTweakPath(k.Path);
            if (k.Delete)
            {
                deleted.Add(path);
                foreach (var key in values.Keys.Where(v => v.Path.StartsWith(path, StringComparison.OrdinalIgnoreCase)).ToList()) values.Remove(key);
                continue;
            }
            deleted.RemoveAll(d => path.StartsWith(d, StringComparison.OrdinalIgnoreCase));
            foreach (var v in k.Values) values[(path, v.Name)] = v.Delete ? null : v;
        }
        Assert.True(values.Count > 400, $"{values.Count} values");
        foreach (var ((path, name), v) in values)
        {
            var got = _h.Get(path, name);
            if (v is null) { Assert.True(got is null, $@"{path}\{name} is still there"); continue; }
            Assert.True(Hex(got) == Hex(Expected(v)), $@"{path}\{name}: {Hex(got)}, not {Hex(Expected(v))}");
            Assert.Equal(v.Kind, _h.Engine.Registry.GetKind(path, name));
        }
        foreach (var d in deleted) Assert.False(_h.Engine.Registry.KeyExists(d), $"{d} is still there");
    }

    private const string Tree = @"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree";

    [Fact]
    public void Startup_entries_and_third_party_tasks_go()
    {
        string[] keys =
        [
            @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", @"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
            @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        ];
        foreach (var k in keys) _h.Set(k, "Updater", "u.exe", "String");
        _h.Set($@"{keys[0]}\Sub", "x", 1, "DWord");
        foreach (var t in new[] { "Microsoft", "GoogleUpdate", "Vendor" }) _h.Set($@"{Tree}\{t}", "Id", "{1}", "String");
        Files(@"%User%\Microsoft\Windows\Start Menu\Programs\Startup\a.lnk", @"%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\b.lnk",
            @"%SystemRoot%\System32\Tasks\Microsoft\Windows\x", @"%SystemRoot%\System32\Tasks\GoogleUpdateTask", @"%SystemRoot%\System32\Tasks\Vendor\y");

        var ps = Blocks("oneclick-startup-cleanup");
        var lines = Lines(ps, "oneclick-startup-cleanup", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("oneclick-startup-cleanup").Kind);
        AssertWrites(_h, Of(lines, "delkey", "newkey"));
        foreach (var k in keys) Assert.Empty(_h.Engine.Registry.ValueNames(k));
        Assert.False(_h.Engine.Registry.KeyExists($@"{keys[0]}\Sub"));

        // the task cache's keys as TrustedInstaller, all but \Microsoft
        var gone = Of(lines, "trustedrun").Select(l => l.Split('\'')[1].Replace(@"Registry::HKEY_LOCAL_MACHINE\", @"HKLM:\")).ToList();
        Assert.Equal([$@"{Tree}\GoogleUpdate", $@"{Tree}\Vendor"], gone.Order());
        foreach (var k in gone) Assert.False(_h.Engine.Registry.KeyExists(k), $"{k} is still there");
        Assert.True(_h.Engine.Registry.KeyExists($@"{Tree}\Microsoft"));
        Assert.True(_h.Trusted.Runs >= 2);

        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.Contains(@"%SystemRoot%\System32\Tasks\Microsoft\Windows\x", _cs.Tree());
    }

    [Fact]
    public void Tools_DDU_gets_ready_before_safe_mode_and_runs_in_it()
    {
        Files(@"%ProgramFiles%\7-Zip\7z.exe", @"%SystemRoot%\Temp\ddu\old.txt");
        var ps = Blocks("tools-ddu-clean,tools-ddu-manual");

        // Prepare: the old folder emptied, DDU unpacked, its settings read only
        var prepare = Lines(ps, "tools-ddu-clean", "Prepare");
        Assert.Null(_h.Engine.Runner.Prepare(_h.Tweak("tools-ddu-clean"), TweakMode.Apply));
        Assert.Equal(PsDid(prepare.Where(l => !l.StartsWith("readonly", StringComparison.Ordinal))), CsDid());
        Assert.Contains(@"readonly %SystemRoot%\Temp\ddu\Settings\Settings.xml|True", prepare);
        Assert.Equal(_ps.Contents(), _cs.Contents());
        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.DoesNotContain(@"%SystemRoot%\Temp\ddu\old.txt", _cs.Tree());

        // not unpacked (the fake 7-Zip unpacks nothing): Apply says DDU is not ready, both ways
        Assert.Equal("throw DDU is not ready (its download before the restart failed)", Lines(ps, "tools-ddu-clean", "Apply").Single());
        var o = _h.Run("tools-ddu-clean", TweakMode.Apply);
        Assert.Equal((OutcomeKind.Failed, "DDU is not ready (its download before the restart failed)"), (o.Kind, o.Message));

        Files(@"%SystemRoot%\Temp\ddu\Display Driver Uninstaller.exe");
        ps = Blocks("tools-ddu-clean,tools-ddu-manual", "-Only", "Apply");
        _h.Exe.Full.Clear();
        _h.Downloads.Saved.Clear();
        _h.Run("tools-ddu-clean", TweakMode.Apply);
        Assert.Equal(PsDid(Lines(ps, "tools-ddu-clean", "Apply")), CsDid());
        _h.Exe.Full.Clear();
        _h.Run("tools-ddu-manual", TweakMode.Apply);
        Assert.Equal(PsDid(Lines(ps, "tools-ddu-manual", "Apply")), CsDid());
        Assert.EndsWith("|True|False", _h.Exe.Full.Single());
    }

    // what the registry engine reads back for a .reg value
    private static object? Expected(RegFileValue v) => v.Kind switch
    {
        RegistryValueKind.ExpandString => Environment.ExpandEnvironmentVariables((string)v.Data!),
        _ => v.Data,
    };

    private static string Norm(string s) => s.Replace("\r\n", "\n").TrimEnd();
}
