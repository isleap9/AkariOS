using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Customize.Apps;

namespace AkariOS.Tweaks.Tests.Customize;

/// <summary>Customize › Apps (g6) on a test key, a temp user folder and fakes: the Store apps' settings hives through
/// the fake IAppSettings, Windows Terminal's settings.json as a file. Compared with the PowerShell blocks run with
/// recorders (Oracle/Invoke-TweakBlocks.ps1: Read- / Import-AkariAppSettings recorded, the real
/// Get-AkariAppSettingState, Stop-Process / Start-Process / Start-Sleep stand-ins) on the same user folder.</summary>
public sealed class AppsTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private readonly string _local;

    public void Dispose() => _h.Dispose();

    // notepad-settings last: its Revert deletes Notepad's settings file, which the badges Tweak needs
    private static readonly string[] HiveIds =
        ["apps-app-actions-off", "apps-notepad-no-new-badges", "apps-photos-no-delete-warning", "apps-store-settings", "apps-notepad-settings"];

    private const string Terminal = "apps-terminal-no-close-tabs-warning";

    public AppsTests()
    {
        _local = _h.Folder(@"User\Local");
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", "Local AppData", _local, "String");
    }

    private string Dat(string id) => AppSettings.Dat(_local, AppHive.Family(_h.Tweak(id)));

    private void MakeDats()
    {
        foreach (var id in HiveIds)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(Dat(id))!);
            File.WriteAllText(Dat(id), "");
        }
    }

    private JsonElement Blocks(string ids, string appValues = "") => appValues.Length == 0
        ? Oracle.Run("Invoke-TweakBlocks.ps1", "-Src", Repo.Src, "-Ids", ids, "-UserFolder", _local)
        : Oracle.Run("Invoke-TweakBlocks.ps1", "-Src", Repo.Src, "-Ids", ids, "-UserFolder", _local, "-AppValues", appValues);

    private static List<string> Lines(JsonElement e, string id, string block, string prefix) =>
        e.GetProperty(id).GetProperty(block).EnumerateArray().Select(l => l.GetString()!)
            .Where(l => l.StartsWith(prefix, StringComparison.Ordinal)).Select(l => l[prefix.Length..]).ToList();

    private static string Hex(byte[] b) => string.Join(",", b.Select(x => x.ToString("x2")));

    // an import as reg.exe reads it: the family, then each value's key, name and bytes (or "-" deleted). The
    // PowerShell app-actions block joins its value lines with spaces (its + runs before -join): a space before the
    // second and third lines, which the C# text doesn't have.
    private static string Imported(string import)
    {
        var (family, text) = (import.Split('|', 2)[0], import.Split('|', 2)[1]);
        var values = RegReader.Parse(text).Keys.SelectMany(k => k.Values.Select(v => $"{k.Path}|{v.Name}|{(v.Delete ? "-" : Hex(v.Raw ?? (byte[])v.Data!))}"));
        return family + " " + string.Join(" ; ", values);
    }

    [Fact]
    public void Every_g6_tweak_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Customize" && t.Category == "Apps"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    // ---- the settings hives

    [Fact]
    public void Each_hive_detect_reads_the_same_family_and_gives_the_same_state_as_get_akariappsettingstate()
    {
        MakeDats();
        var rows = HiveIds.SelectMany(id => AppHive.Rows(_h.Tweak(id))).ToList();
        Assert.Equal(11, rows.Count);
        // the same values in every family, as the recorder hands them out
        var scenarios = new Dictionary<string, Dictionary<string, byte[]>?>
        {
            ["none"] = [],
            ["optimized"] = rows.DistinctBy(r => r.Name).ToDictionary(r => r.Name, r => new[] { (byte)r.Value, (byte)0x3c }),
            ["windows"] = rows.DistinctBy(r => r.Name).ToDictionary(r => r.Name, r => new[] { (byte)r.Default }),
            ["custom"] = rows.DistinctBy(r => r.Name).Select((r, i) => (r, i)).ToDictionary(x => x.r.Name, x => new[] { (byte)(x.i % 2 == 0 ? x.r.Value : 7) }),
            ["held"] = null,
        };
        foreach (var (name, values) in scenarios)
        {
            var arg = values is null ? "held" : string.Join(";", values.Select(v => $"{v.Key}={Hex(v.Value)}"));
            var ps = Blocks(string.Join(",", HiveIds), arg);
            MakeDats();
            foreach (var id in HiveIds)
            {
                var family = AppHive.Family(_h.Tweak(id));
                _h.Apps.Held.Clear();
                if (values is null) _h.Apps.Held.Add(family);
                else _h.Apps.Hives[family] = new(values, StringComparer.OrdinalIgnoreCase);
                Assert.Equal([family], Lines(ps, id, "Detect", "appread "));
                Assert.True(Lines(ps, id, "Detect", "result ").Single() == _h.State(id).ToString(), $"{id} ({name})");
            }
        }
    }

    [Fact]
    public void Each_hive_change_stops_the_same_programs_and_imports_the_same_reg_text_as_the_powershell_blocks()
    {
        MakeDats();
        var ps = Blocks(string.Join(",", HiveIds));
        MakeDats();
        foreach (var id in HiveIds)
            foreach (var (block, mode) in new[] { ("Apply", TweakMode.Apply), ("Revert", TweakMode.Revert) })
            {
                _h.Processes.Stopped.Clear();
                _h.Apps.Imports.Clear();
                _h.Launcher.Opened.Clear();
                var o = _h.Run(id, mode);
                Assert.True(o.Kind is OutcomeKind.Applied or OutcomeKind.Reverted, $"{id} {block}: {o.Kind} {o.Message}");
                Assert.Equal(Lines(ps, id, block, "stop "), _h.Processes.Stopped);
                Assert.Equal(Lines(ps, id, block, "open "), _h.Launcher.Opened);
                Assert.Equal(Lines(ps, id, block, "appimport ").Select(Imported), _h.Apps.Imports.Select(Imported));
                // what the change did to the user's files (Notepad's Revert deletes its settings file)
                Assert.Equal(Lines(ps, id, block, "file ").Select(f => f.Split('|')[0]).Order(StringComparer.Ordinal),
                    Directory.GetFiles(_local, "*", SearchOption.AllDirectories).Order(StringComparer.Ordinal).Select(f => Path.GetRelativePath(_local, f)));
            }
        Assert.False(File.Exists(Dat("apps-notepad-settings")));
    }

    [Fact]
    public void A_change_reads_back_as_its_state()
    {
        MakeDats();
        foreach (var id in HiveIds.Where(i => i != "apps-notepad-settings"))
        {
            Assert.Equal(TweakState.Default, _h.State(id));
            _h.Run(id, TweakMode.Apply);
            Assert.Equal(TweakState.Optimized, _h.State(id));
            var o = _h.Run(id, TweakMode.Revert);
            Assert.True(_h.State(id) == TweakState.Default, $"{id}: {o.Kind} {o.Message}");
        }
    }

    [Fact]
    public void App_actions_have_nothing_to_change_while_the_shell_has_no_settings_file()
    {
        Assert.Equal(OutcomeKind.Applied, _h.Run("apps-app-actions-off", TweakMode.Apply).Kind);
        Assert.Empty(_h.Apps.Imports);
        Assert.Contains(_h.Log.Lines, l => l.Contains("nothing to change", StringComparison.Ordinal));
    }

    [Fact]
    public void A_hive_the_app_holds_fails_with_the_blocks_own_message()
    {
        MakeDats();
        var held = AppHive.Family(_h.Tweak("apps-photos-no-delete-warning"));
        _h.Apps.Held.Add(held);
        // a held hive reads as Unknown, so the Runner goes ahead
        var o = _h.Run("apps-photos-no-delete-warning", TweakMode.Apply);
        Assert.Equal(OutcomeKind.Failed, o.Kind);
        Assert.Contains("the Photos app's settings could not be opened (close Photos", o.Message);
    }

    // ---- Windows Terminal

    private string TerminalFile => Path.Combine(_local, @"Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json");

    [Theory]
    [InlineData("{\r\n    \"$help\": \"https://aka.ms/terminal-documentation\",\r\n    \"profiles\": {}\r\n}\r\n")]
    [InlineData("{}")]
    [InlineData("// comment\n{\n    \"confirmCloseAllTabs\": true,\n    \"x\": 1\n}\n")]
    [InlineData("{\n    \"x\": 1,\n    \"confirmCloseAllTabs\" : FALSE\n}\n")]
    [InlineData("{\n  \"confirmCloseAllTabs\": 0\n}")]
    public void Terminal_settings_are_edited_as_the_powershell_helpers_edit_them(string text)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(TerminalFile)!);
        File.WriteAllText(TerminalFile, text);
        var ps = Blocks(Terminal);
        string FileAfter(string block) => Lines(ps, Terminal, block, "file ").Single().Split('|', 2)[1];

        Assert.Equal(Lines(ps, Terminal, "Detect", "result ").Single(), TerminalCloseTabs.StateOf(text).ToString());
        var applied = TerminalCloseTabs.Edit(text, true);
        Assert.Equal(FileAfter("Apply"), applied);
        Assert.Equal(FileAfter("Revert"), TerminalCloseTabs.Edit(applied, false));
    }

    [Fact]
    public void Terminal_is_unknown_without_a_settings_file_and_its_change_writes_the_file()
    {
        Assert.Equal(TweakState.Unknown, _h.State(Terminal));
        Assert.Equal(OutcomeKind.Failed, _h.Run(Terminal, TweakMode.Apply).Kind);

        Directory.CreateDirectory(Path.GetDirectoryName(TerminalFile)!);
        File.WriteAllText(TerminalFile, "{\n    \"x\": 1\n}\n");
        Assert.Equal(TweakState.Default, _h.State(Terminal));
        Assert.Equal(OutcomeKind.Applied, _h.Run(Terminal, TweakMode.Apply).Kind);
        Assert.Equal("{\n    \"confirmCloseAllTabs\": false,\n    \"x\": 1\n}\n", File.ReadAllText(TerminalFile));
        Assert.Equal(TweakState.Optimized, _h.State(Terminal));
        var r = _h.Run(Terminal, TweakMode.Revert);
        Assert.True(r.Kind == OutcomeKind.Reverted, $"{r.Kind} {r.Message}");
        Assert.Equal("{\n    \"x\": 1\n}\n", File.ReadAllText(TerminalFile));
    }
}
