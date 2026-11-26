using System.IO.Compression;
using System.Text.Json;
using AkariOS.Core.Support;

namespace AkariOS.Core.Tests;

/// <summary>
/// The support file (X1): the names taken out as src\Core\Support.ps1 takes them (Oracle/Export-Support.ps1), and the
/// zip's entries. Files in a temp folder only.
/// </summary>
public sealed class SupportTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-support-{Guid.NewGuid():N}");

    public SupportTests() => Directory.CreateDirectory(_dir);

    public void Dispose() => Directory.Delete(_dir, true);

    private static readonly (string Text, string[] Users, string Computer)[] Cases =
    [
        (@"C:\Users\Bob\AppData and ""C:\\Users\\Bob\\x"" and c:/users/Bob/y", [], ""),
        (@"C:\Users\Public\Desktop C:\Users\Default\x C:\Users\Publicity\y C:\Users\All Users\z", [], ""),
        ("bob ran on DESKTOP-1 as BOB; bobby stays; desktop-1x stays", ["Bob"], "desktop-1"),
        ("Ann Lee and Ann", ["Ann", "Ann Lee"], ""),
        ("a b", ["a", " ", ""], "b"),
        ("", ["Bob"], "PC"),
        ("j.d+ and jxd, $1 cost", ["j.d+", "$1"], ""),
        ("Élodie at ÉLODIE-PC: C:\\Users\\Élodie\\x\r\nnext line C:\\Users\\Élodie", ["Élodie"], "élodie-pc"),
        ("D:\\Users\\Sam\\Games and ProgramData\\Users\\x", ["Sam"], "SAM-PC"),
        ("multi\nline\r\nbob\n", ["bob"], ""),
    ];

    private static readonly Lazy<JsonElement> PowerShell = new(() =>
    {
        var cases = Path.Combine(Path.GetTempPath(), $"akari-support-cases-{Guid.NewGuid():N}.json");
        File.WriteAllText(cases, JsonSerializer.Serialize(Cases.Select(c => new { c.Text, c.Users, c.Computer })));
        try { return Oracle.Run("Export-Support.ps1", "-Src", Repo.Src, "-Cases", cases); }
        finally { File.Delete(cases); }
    });

    [Fact]
    public void Scrub_is_powershells()
    {
        var ps = PowerShell.Value.EnumerateArray().Select(e => e.GetString()).ToList();
        Assert.Equal(Cases.Length, ps.Count);
        for (var i = 0; i < Cases.Length; i++)
            Assert.Equal(ps[i], SupportFile.Scrub(Cases[i].Text, Cases[i].Users, Cases[i].Computer));
    }

    [Fact]
    public void Scrub_takes_names_out()
    {
        Assert.Equal(@"C:\Users\<user>\x on <pc>", SupportFile.Scrub(@"C:\Users\Bob\x on PC1", ["Bob"], "PC1"));
        Assert.Equal(@"C:\Users\Public\x", SupportFile.Scrub(@"C:\Users\Public\x", [], ""));
    }

    private static Dictionary<string, string> Read(string zip)
    {
        using var z = ZipFile.OpenRead(zip);
        return z.Entries.ToDictionary(e => e.FullName, e => { using var r = new StreamReader(e.Open()); return r.ReadToEnd(); });
    }

    [Fact]
    public void Make_adds_the_files_that_exist_scrubbed_and_system_txt()
    {
        var log = Path.Combine(_dir, "akari.log");
        File.WriteAllText(log, @"Bob saved C:\Users\Bob\x on PC1");
        var state = Path.Combine(_dir, "state.json");
        File.WriteAllText(state, "{}");
        var zip = Path.Combine(_dir, "out.zip");
        File.WriteAllText(zip, "old");
        int count;
        // a file another program holds open is read too
        using (new FileStream(log, FileMode.Open, FileAccess.ReadWrite, FileShare.ReadWrite))
            count = SupportFile.Make(zip, [log, state, log, Path.Combine(_dir, "missing.json"), null, ""], ["AkariOS 1", "PC: PC1"], ["Bob"], "PC1");
        Assert.Equal(2, count);
        var e = Read(zip);
        Assert.Equal(["akari.log", "state.json", "system.txt"], e.Keys.ToArray());
        Assert.Equal(@"<user> saved C:\Users\<user>\x on <pc>", e["akari.log"]);
        Assert.Equal("AkariOS 1\r\nPC: <pc>\r\n", e["system.txt"]);
    }

    [Fact]
    public void Virtual_names_are_powershells_list()
    {
        Assert.True(SupportFile.IsVirtual("innotek GmbH", "VirtualBox"));
        Assert.True(SupportFile.IsVirtual("Microsoft Corporation", "Virtual Machine"));
        Assert.True(SupportFile.IsVirtual("QEMU", "Standard PC"));
        Assert.False(SupportFile.IsVirtual("ASUS", "ROG STRIX B650"));
        Assert.False(SupportFile.IsVirtual("Kvmtech", ""));
    }
}
