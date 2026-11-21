using AkariOS.Core.Iso;

namespace AkariOS.Core.Tests;

/// <summary>Windows 11 from Microsoft's page (batch I5, native only): its published SHA-256 table read, the browser's
/// download found in Downloads and checked against it.</summary>
public sealed class MicrosoftIsoTests
{
    private static string Fixture() => File.ReadAllText(Path.Combine(Repo.Root, "tests", "Fixtures", "Iso", "microsoft-windows11.html"));

    [Fact]
    public void Reads_the_pages_hash_table()
    {
        var rows = MicrosoftIso.Hashes(Fixture());
        Assert.Equal(["Arabic 64-bit", "Bulgarian 64-bit", "Chinese Traditional 64-bit", "Português 64-bit"], rows.Select(r => r.Language));
        // whitespace and lower case in a cell, an entity in a name
        Assert.Equal("E951AB4EAD95D45E00CDFF6C9C05836F9499D3FD2FDEEAE0E709549F12F9B5DC", rows[2].Sha256);
        Assert.Empty(MicrosoftIso.Hashes("<table><tr><td>English</td><td>not a hash</td></tr></table>"));
    }

    [Fact]
    public void Matches_a_hash_in_any_case()
    {
        var rows = MicrosoftIso.Hashes(Fixture());
        Assert.Equal("Arabic 64-bit", MicrosoftIso.Match(rows, "a75ae3f36cb9ffffedcb2d7ded9cef83ffb710eb1376610d2220684d987cb9a5")?.Language);
        Assert.Null(MicrosoftIso.Match(rows, new string('0', 64)));
    }

    private static (IsoDownloadOracleTests.Side Side, IsoDownload Download, DownloadFakes Fakes) Make(string? page)
    {
        var c = IsoDownloadOracleTests.Case();
        c["Pages"] = new Dictionary<string, string?> { [MicrosoftIso.Page] = page };
        var side = new IsoDownloadOracleTests.Side(c);
        var fakes = new DownloadFakes(side.Root, c);
        return (side, new IsoDownload(fakes.Parts), fakes);
    }

    [Fact]
    public void Reads_microsofts_list_and_says_why_when_it_cant()
    {
        var (s1, ok, f1) = Make(Fixture());
        using (s1)
        {
            var r = ok.MicrosoftHashes();
            Assert.True(r.Ok);
            Assert.Equal(4, r.Value!.Count);
            Assert.Equal([$"Page {MicrosoftIso.Page}"], f1.Calls);
        }
        var (s2, empty, _) = Make("<html>no table</html>");
        using (s2) Assert.Equal("Microsoft's page lists no SHA-256 values (its layout may have changed).", empty.MicrosoftHashes().Message);
        var (s3, gone, _) = Make(null);
        using (s3) Assert.Equal("Couldn't read Microsoft's SHA-256 list: 404 Not Found", gone.MicrosoftHashes().Message);
    }

    [Fact]
    public void Finds_a_new_win11_iso_in_downloads_and_checks_it()
    {
        var (side, dl, _) = Make(Fixture());
        using var _s = side;
        var downloads = Path.Combine(side.Root, "downloads");
        var since = DateTime.UtcNow.AddMinutes(-1);
        var old = Path.Combine(downloads, "Win11_24H2_English_x64.iso");
        File.WriteAllText(old, "old");
        File.SetLastWriteTimeUtc(old, since.AddHours(-1));
        File.WriteAllText(Path.Combine(downloads, "Win11_25H2_English_x64.iso.crdownload"), "partial");
        File.WriteAllText(Path.Combine(downloads, "other.iso"), "not microsoft's");
        Assert.Null(dl.FindNew(MicrosoftIso.FilePattern, since));

        var iso = Path.Combine(downloads, "Win11_25H2_English_x64.iso");
        File.WriteAllText(iso, "iso bytes");
        Assert.Equal(iso, dl.FindNew(MicrosoftIso.FilePattern, since));

        var sha = IsoReport.Sha256Of(iso);
        Assert.Equal("English 64-bit", dl.Check(iso, [new("Arabic 64-bit", new string('A', 64)), new("English 64-bit", sha.ToUpperInvariant())])?.Language);
        Assert.Null(dl.Check(iso, MicrosoftIso.Hashes(Fixture())));
    }
}
