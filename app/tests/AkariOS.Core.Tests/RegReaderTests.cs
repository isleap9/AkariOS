using System.Globalization;
using System.Text;
using System.Text.Json;
using AkariOS.Core.Data;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

public class RegReaderTests
{
    private const string Header = "Windows Registry Editor Version 5.00\r\n\r\n";

    private static RegFileValue One(string valueLine) =>
        Assert.Single(Assert.Single(RegReader.Parse(Header + "[HKEY_CURRENT_USER\\Software\\X]\r\n" + valueLine).Keys).Values);

    [Fact]
    public void Reads_keys_and_deleted_keys()
    {
        var f = RegReader.Parse(Header + "; a comment\r\n[HKEY_CURRENT_USER\\Software\\A]\r\n\"V\"=dword:00000001\r\n\r\n[-HKEY_LOCAL_MACHINE\\SOFTWARE\\B]\r\n");
        Assert.Equal(5, f.Version);
        Assert.Equal(2, f.Keys.Count);
        Assert.Equal((@"HKEY_CURRENT_USER\Software\A", false, 4), (f.Keys[0].Path, f.Keys[0].Delete, f.Keys[0].Line));
        Assert.True(f.Keys[1].Delete);
        Assert.Empty(f.Keys[1].Values);
    }

    [Theory]
    [InlineData("\"V\"=dword:ffffffff", RegistryValueKind.DWord, 0xFFFFFFFFu)]
    [InlineData("\"V\"=hex(4):01,00,00,00", RegistryValueKind.DWord, 1u)]
    [InlineData("\"V\"=hex(b):00,e4,0b,54,02,00,00,00", RegistryValueKind.QWord, 10000000000ul)]
    [InlineData("\"V\"=\"C:\\\\Windows \\\"x\\\"\"", RegistryValueKind.String, "C:\\Windows \"x\"")]
    [InlineData("@=\"\"", RegistryValueKind.String, "")]
    [InlineData("\"V\"=hex(2):25,00,53,00,79,00,73,00,25,00,00,00", RegistryValueKind.ExpandString, "%Sys%")]
    public void Reads_each_type(string line, RegistryValueKind kind, object data)
    {
        var v = One(line);
        Assert.Equal(kind, v.Kind);
        Assert.Equal(data, v.Data);
        Assert.False(v.Delete);
    }

    [Fact]
    public void The_unnamed_value_is_default() => Assert.Equal("(default)", One("@=\"x\"").Name);

    [Fact]
    public void Binary_multi_string_and_custom_types()
    {
        Assert.Equal(new byte[] { 0x90, 0x12 }, One("\"V\"=hex:90,12").Data);
        Assert.Equal(new[] { "a", "bc" }, One("\"V\"=hex(7):61,00,00,00,62,00,63,00,00,00,00,00").Data);
        var store = One("\"VideoAutoplay\"=hex(5f5e10b):00,96,9d");
        Assert.Equal((RegistryValueKind.Unknown, 0x5f5e10b), (store.Kind, store.RawType));
        Assert.Equal(new byte[] { 0, 0x96, 0x9d }, store.Data);
    }

    [Fact]
    public void A_deleted_value() => Assert.True(One("\"V\"=-").Delete);

    [Fact]
    public void Long_hex_values_continue_on_the_next_line()
    {
        Assert.Equal(new byte[] { 1, 2, 3, 4, 5 }, One("\"V\"=hex:01,02,\\\r\n  03,04,\\\r\n  05").Data);
        var f = RegReader.Parse(Header + "[HKEY_CURRENT_USER\\X]\r\n\"P\"=\"C:\\\\\"\r\n\"Q\"=dword:00000001");
        Assert.Equal(["P", "Q"], f.Keys[0].Values.Select(x => x.Name));
        Assert.Equal("C:\\", f.Keys[0].Values[0].Data);
    }

    [Fact]
    public void Regedit4_text_is_ansi()
    {
        var f = RegReader.Parse("REGEDIT4\r\n\r\n[HKEY_CURRENT_USER\\X]\r\n\"V\"=hex(2):25,41,25,00");
        Assert.Equal(4, f.Version);
        Assert.Equal("%A%", f.Keys[0].Values[0].Data);
    }

    [Fact]
    public void Utf16_files_decode()
    {
        var bytes = Encoding.Unicode.GetPreamble().Concat(Encoding.Unicode.GetBytes(Header + "[HKEY_USERS\\S-1]\r\n")).ToArray();
        Assert.Equal(@"HKEY_USERS\S-1", RegReader.Parse(RegReader.Decode(bytes)).Keys[0].Path);
    }

    [Theory]
    [InlineData("not a reg file\r\n", 1)]
    [InlineData(Header + "\"V\"=dword:1\r\n", 3)]
    [InlineData(Header + "[HKEY_CURRENT_USER\\X]\r\n\"V\"=dword:zz\r\n", 4)]
    [InlineData(Header + "[HKEY_CURRENT_USER\\X]\r\n\"V\"=hex(b):01\r\n", 4)]
    [InlineData(Header + "[HKEY_CURRENT_USER\\X\r\n", 3)]
    [InlineData(Header + "[-HKEY_CURRENT_USER\\X]\r\n\"V\"=dword:1\r\n", 4)]
    public void Broken_text_says_where(string text, int line) =>
        Assert.Equal(line, Assert.Throws<PsDataException>(() => RegReader.Parse(text)).Line);

    [Theory]
    [InlineData(@"HKEY_CURRENT_USER\Software\X", @"HKCU:\Software\X")]
    [InlineData(@"HKEY_LOCAL_MACHINE\SYSTEM", @"HKLM:\SYSTEM")]
    [InlineData(@"HKEY_CLASSES_ROOT\*\shell", @"HKLM:\SOFTWARE\Classes\*\shell")]
    [InlineData(@"HKEY_USERS\.DEFAULT\X", @"Registry::HKEY_USERS\.DEFAULT\X")]
    public void Paths_as_tweak_rows_write_them(string reg, string tweak) => Assert.Equal(tweak, RegReader.ToTweakPath(reg));

    // ---- the shared files, against the PowerShell app's readers

    private static readonly Lazy<JsonElement> PowerShell = new(() =>
        Oracle.Run("Export-RegFile.ps1", "-Repo", Repo.Root));

    private static string Shared(string rel) => File.ReadAllText(Path.Combine(Repo.Root, rel));

    [Fact]
    public void Reg_reg_reads_as_the_marks_test_reads_it()
    {
        var mine = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        foreach (var key in RegReader.Parse(Shared(@"src\OneClick\reg.reg")).Keys)
        {
            var path = RegReader.ToTweakPath(key.Path).ToLowerInvariant();
            if (key.Delete) { mine[path + "|"] = null; continue; }
            foreach (var v in key.Values) mine[$"{path}|{v.Name.ToLowerInvariant()}"] = AsMarksTestReadsIt(v);
        }
        Compare(PowerShell.Value.GetProperty("RegReg"), mine);
    }

    [Fact]
    public void Store_settings_read_as_ConvertFrom_AkariRegExport_reads_them()
    {
        const string root = @"HKEY_LOCAL_MACHINE\AkariAppHive";
        var mine = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        var text = Shared(@"src\Tweaks\Customize\Apps\Files\store-settings.reg").Replace("{0}", "00");
        foreach (var key in RegReader.Parse(text).Keys.Where(k => k.Path.StartsWith(root, StringComparison.OrdinalIgnoreCase)))
        {
            var rel = key.Path.Length == root.Length ? "" : key.Path[(root.Length + 1)..];
            foreach (var v in key.Values.Where(v => v.Data is byte[]))
                mine[rel.Length == 0 ? v.Name : $@"{rel}\{v.Name}"] = v.Data;
        }
        Assert.NotEmpty(mine);
        Compare(PowerShell.Value.GetProperty("Store"), mine);
    }

    // tests\RegFile.ps1's reading: UserPreferencesMask's hex(2) as bytes, an empty multi-string as one empty string
    private static object? AsMarksTestReadsIt(RegFileValue v)
    {
        if (v.Delete) return null;
        if (v.RawType == 2 && v.Name.Equals("UserPreferencesMask", StringComparison.OrdinalIgnoreCase))
            return v.Raw;
        if (v.Data is string[] { Length: 0 }) return new[] { "" };
        return v.Data;
    }

    private static void Compare(JsonElement ps, Dictionary<string, object?> mine)
    {
        var diffs = new List<string>();
        var theirs = ps.EnumerateObject().ToDictionary(p => p.Name, p => p.Value, StringComparer.OrdinalIgnoreCase);
        foreach (var k in theirs.Keys.Where(k => !mine.ContainsKey(k))) diffs.Add($"{k}: only in PowerShell's");
        foreach (var (k, v) in mine)
        {
            if (!theirs.TryGetValue(k, out var p)) { diffs.Add($"{k}: only in RegReader's"); continue; }
            var same = v switch
            {
                null => p.ValueKind == JsonValueKind.Null,
                string s => p.ValueKind == JsonValueKind.String && p.GetString() == s,
                string[] a => p.ValueKind == JsonValueKind.Array && p.EnumerateArray().Select(x => x.GetString()).SequenceEqual(a),
                // Read-AkariRegFile's switch hands its byte arrays on as lists of bytes
                byte[] b => p.ValueKind == JsonValueKind.Object && p.TryGetProperty("$bytes", out var h) && h.GetString() == Convert.ToHexString(b).ToLowerInvariant()
                            || p.ValueKind == JsonValueKind.Array && p.EnumerateArray().Select(x => x.GetProperty("$num").GetString()).SequenceEqual(b.Select(x => x.ToString(CultureInfo.InvariantCulture))),
                uint or ulong => p.ValueKind == JsonValueKind.Object && p.TryGetProperty("$num", out var n) &&
                                 n.GetString() == Convert.ToString(v, CultureInfo.InvariantCulture) && p.GetProperty("$type").GetString() == v.GetType().Name,
                _ => false,
            };
            if (!same) diffs.Add($"{k}: {v}, PowerShell has {p}");
        }
        Assert.True(diffs.Count == 0, $"{diffs.Count} differences:\n" + string.Join("\n", diffs.Take(40)));
        Assert.True(mine.Count > 0);
    }
}
