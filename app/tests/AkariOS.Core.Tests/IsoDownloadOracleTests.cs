using System.IO.Compression;
using System.Text.Json;
using AkariOS.Core.Iso;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;

namespace AkariOS.Core.Tests;

/// <summary>
/// IsoDownload against src\Core\IsoDownload.ps1 (Oracle/Invoke-IsoDownload.ps1): the real UUP Dump calls with
/// retries, the converter package and its run, Massgrave's catalogue and the Downloads search, with recorders in place
/// of the network and the converter; IsoDownload with recording fakes answering the same case. Compared: the calls
/// (Api, Package, Script, Ini (ConvertConfig.ini's bytes when the converter runs), Page, Sleep), the log and akari.log
/// lines, each action's result, the files left in the output folder.
/// </summary>
public sealed partial class IsoDownloadOracleTests
{
    // the case, Side: IsoShared.cs

    private static object Save(string? virtualEdition = null, string label = "Pro") => new
    {
        Do = "Save", Version = "25H2", Lang = "en-us",
        Build = new { Id = BuildId, Title = "Windows 11, version 25H2", Build = "26200.6584" },
        Target = new { Label = label, Code = "PROFESSIONAL", Virtual = virtualEdition ?? "" },
    };

    internal sealed record Output(List<string> Calls, List<string> Log, List<string> ErrLog, List<string> Results, List<string> Files);

    private static List<string> Strings(JsonElement e) => [.. e.EnumerateArray().Select(i => i.GetString()!)];

    private static Output Ps(Side s, Dictionary<string, object> c)
    {
        var file = Path.Combine(s.Root, "case.json");
        File.WriteAllText(file, IsoBuildOracleTests.Json(c));
        var r = Oracle.Run("Invoke-IsoDownload.ps1", ["-Src", Repo.Src, "-Case", file, "-Root", s.Root]);
        File.Delete(file);
        return new Output(Strings(r.GetProperty("Calls")), Strings(r.GetProperty("Log")), Strings(r.GetProperty("ErrLog")), Strings(r.GetProperty("Results")), s.Files());
    }

    private static string B(bool ok) => ok ? "True" : "False";

    internal static Output Cs(Side s, Dictionary<string, object> c, Action<DownloadFakes>? tune = null)
    {
        var f = new DownloadFakes(s.Root, c);
        tune?.Invoke(f);
        var d = new IsoDownload(f.Parts);
        var results = new List<string>();
        var outDir = Path.Combine(s.Root, "out");
        foreach (var a in f.Case.GetProperty("Actions").EnumerateArray())
        {
            string P(string name) => a.GetProperty(name).GetString()!;
            switch (P("Do"))
            {
                case "Build":
                    var b = d.Build(P("Version"));
                    results.Add($"Build;Ok={B(b.Ok)};Value={(b.Ok ? $"{b.Value!.Id}|{b.Value.Title}|{b.Value.Build}" : "")};Message={f.Norm(b.Message)}");
                    break;
                case "Languages":
                    var l = d.Languages(P("Id"));
                    results.Add($"Languages;Ok={B(l.Ok)};Value={(l.Ok ? string.Join(",", l.Value!.Select(x => $"{x.Code}:{x.Name}")) : "")};Message={f.Norm(l.Message)}");
                    break;
                case "Editions":
                    var e = d.Editions(P("Id"), P("Lang"));
                    results.Add($"Editions;Ok={B(e.Ok)};Value={(e.Ok ? string.Join(",", e.Value!.Select(x => $"{x.Label}|{x.Code}|{x.Virtual}")) : "")};Message={f.Norm(e.Message)}");
                    break;
                case "Save":
                    var bd = a.GetProperty("Build");
                    var t = a.GetProperty("Target");
                    var r = d.SaveUup(P("Version"), new UupBuild(bd.GetProperty("Id").GetString()!, bd.GetProperty("Title").GetString()!, bd.GetProperty("Build").GetString()!, ""),
                        P("Lang"), new UupTarget(t.GetProperty("Label").GetString()!, t.GetProperty("Code").GetString()!, t.GetProperty("Virtual").GetString()!), outDir);
                    results.Add($"Save;Ok={B(r.Ok)};Value={f.Norm(r.Path ?? "")};Message={f.Norm(r.Message)}");
                    break;
                case "Catalogue":
                    var m = d.Catalogue();
                    results.Add($"Catalogue;Ok={B(m.Ok)};Value={string.Join(",", (m.Value ?? []).Select(x => $"{x.Product}|{x.Language}|{x.File}|{x.Url}"))};Message={f.Norm(m.Message)}");
                    break;
                case "Find":
                    results.Add($"Find;Value={f.Norm(d.FindDownloaded(P("File"), Path.Combine(s.Root, "downloads")) ?? "")}");
                    break;
            }
        }
        return new Output(f.Calls, [.. f.Log.Lines.Select(f.Norm)], [.. f.Log.FileLines.Select(f.Norm)], results, s.Files());
    }

    private static Output Same(Dictionary<string, object> c)
    {
        using var ps = new Side(c);
        using var cs = new Side(c);
        var p = Ps(ps, c);
        var n = Cs(cs, c);
        Assert.Equal(p.Results, n.Results);
        Assert.Equal(p.Calls, n.Calls);
        Assert.Equal(p.Log, n.Log);
        Assert.Equal(p.ErrLog, n.ErrLog);
        Assert.Equal(p.Files, n.Files);
        return n;
    }

    // ---- UUP Dump's API

    [Fact]
    public void Finds_the_newest_release_build()
    {
        var c = Case(new { Do = "Build", Version = "25H2" });
        c["Answers"] = new[] { ListId };
        var o = Same(c);
        Assert.Equal($"Build;Ok=True;Value={BuildId}|Windows 11, version 25H2 (26200.6584) amd64|26200.6584;Message=", o.Results[0]);
        Assert.Equal(["Api listid search=windows 11 26200 amd64&sortByDate=1"], o.Calls);
    }

    [Fact]
    public void Refuses_an_unknown_version() => Same(Case(new { Do = "Build", Version = "21H2" }));

    [Fact]
    public void Says_when_there_is_no_release_build()
    {
        var c = Case(new { Do = "Build", Version = "26H2" });
        c["Answers"] = new[] { ListId };
        Same(c);
    }

    [Fact]
    public void Tries_three_times_with_a_pause_then_gives_up()
    {
        var c = Case(new { Do = "Languages", Id = BuildId });
        c["Answers"] = new[] { Fail("The operation has timed out."), Fail("Unable to connect to the remote server"), Fail("The remote server returned an error: (429) Too Many Requests.") };
        var o = Same(c);
        Assert.Equal(["Sleep 5", "Sleep 5"], o.Calls.Where(x => x.StartsWith("Sleep", StringComparison.Ordinal)));
    }

    [Fact]
    public void Answers_after_a_retry()
    {
        var c = Case(new { Do = "Languages", Id = BuildId });
        c["Answers"] = new[] { Fail("The operation has timed out."), ListLangs };
        var o = Same(c);
        Assert.Equal("Languages;Ok=True;Value=en-us:English (United States),fr-fr:French,de-de:German;Message=", o.Results[0]);
    }

    [Fact]
    public void Stops_at_an_error_uup_dump_answers()
    {
        var c = Case(new { Do = "Editions", Id = BuildId, Lang = "xx-xx" });
        c["Answers"] = new[] { Ok(new { error = "UNSUPPORTED_LANG" }) };
        Same(c);
    }

    [Fact]
    public void Lists_the_editions_and_the_virtual_ones()
    {
        var c = Case(new { Do = "Editions", Id = BuildId, Lang = "en-us" });
        c["Answers"] = new[] { ListEditions };
        Same(c);
    }

    // ---- the converter

    [Fact]
    public void Downloads_an_edition_through_the_converter()
    {
        var o = Same(Case(Save()));
        Assert.Equal(@"Save;Ok=True;Value=<root>\out\Windows11_25H2_Pro_en-us.iso;Message=", o.Results[0]);
        Assert.Equal([@"<root>\out\Windows11_25H2_Pro_en-us.iso"], o.Files);
        Assert.Contains("Done", o.Log);
    }

    [Fact]
    public void Makes_a_virtual_edition_from_pro()
    {
        var o = Same(Case(Save("IoTEnterprise", "IoT Enterprise")));
        var ini = System.Text.Encoding.ASCII.GetString(Convert.FromBase64String(o.Calls.Single(x => x.StartsWith("Ini ", StringComparison.Ordinal))[4..]));
        Assert.Contains("vAutoEditions=IoTEnterprise\r\n", ini);
        Assert.Contains("StartVirtual=1\r\n", ini);
        Assert.Contains("AutoExit=1\r\n", ini);
        Assert.EndsWith("AutoExit=1\r\n", ini);
        Assert.Contains($"Package https://uupdump.net/get.php?id={BuildId}&pack=en-us&edition=professional autodl=3&cleanup=1&updates=1&virtualEditions[]=IoTEnterprise", o.Calls);
        Assert.Equal([@"<root>\out\Windows11_25H2_IoT-Enterprise_en-us.iso"], o.Files);
    }

    [Fact]
    public void Looks_in_the_real_users_downloads_by_default()
    {
        var c = Case();
        c["Downloads"] = new object[] { new { Name = "win.iso", Age = 1 } };
        using var s = new Side(c);
        var f = new DownloadFakes(s.Root, c);
        Assert.Equal(Path.Combine(s.Root, "downloads", "win.iso"), new IsoDownload(f.Parts).FindDownloaded("win.iso"));
        Assert.Null(new IsoDownload(f.Parts with { Downloads = () => null }).FindDownloaded("win.iso"));
    }

    [Fact]
    public void The_real_runner_and_downloads_refuse_to_run_under_test()
    {
        Assert.Throws<InvalidOperationException>(() => new ExeRunner());
        Assert.Throws<InvalidOperationException>(() => new HttpDownloads());
    }

    [Fact]
    public void Fails_when_the_converter_fails()
    {
        var c = Case(Save());
        c["Script"] = new { Code = 1, Iso = "", Lines = new[] { "Error: aria2 could not download" } };
        Same(c);
    }

    [Fact]
    public void Fails_when_the_converter_makes_no_iso()
    {
        var c = Case(Save());
        c["Script"] = new { Code = 0, Iso = "", Lines = Array.Empty<string>() };
        Same(c);
    }

    [Fact]
    public void Fails_when_the_package_has_no_config()
    {
        var c = Case(Save());
        c["Package"] = new { Files = new Dictionary<string, string> { ["uup_download_windows.cmd"] = "@echo off" } };
        Same(c);
    }

    [Fact]
    public void Fails_when_the_package_will_not_download()
    {
        var c = Case(Save());
        c["Package"] = new { Throw = "The remote server returned an error: (500) Internal Server Error." };
        Same(c);
    }

    [Fact]
    public void Refuses_a_drive_too_small_for_the_download()
    {
        var c = Case(Save());
        c["Drive"] = new { Free = 5L << 30, Format = "NTFS" };
        Same(c);
    }

    // ---- Massgrave

    [Fact]
    public void Reads_both_massgrave_pages()
    {
        var c = Case(new { Do = "Catalogue" });
        c["Pages"] = new Dictionary<string, string?>
        {
            [Massgrave.Pages[0]] = Page("Windows 11 Consumer 25H2", "en-us_windows_11_consumer_editions_version_25h2_x64_dvd.iso"),
            [Massgrave.Pages[1]] = Page("Windows 11 IoT Enterprise LTSC 2024", "en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd.iso", "en-us_windows_10_ltsc_x64.iso"),
        };
        var o = Same(c);
        Assert.Equal(2, o.Results[0].Split(',').Length);
    }

    [Fact]
    public void Says_when_massgrave_cannot_be_read() => Same(Case(new { Do = "Catalogue" }));

    [Fact]
    public void Says_when_massgrave_lists_no_windows_11()
    {
        var c = Case(new { Do = "Catalogue" });
        c["Pages"] = new Dictionary<string, string?> { [Massgrave.Pages[0]] = "# nothing", [Massgrave.Pages[1]] = "# nothing" };
        Same(c);
    }

    // ---- the browser's download

    [Fact]
    public void Finds_the_newest_copy_a_browser_saved()
    {
        var c = Case(new { Do = "Find", File = "win.iso" }, new { Do = "Find", File = "other.iso" });
        c["Downloads"] = new object[]
        {
            new { Name = "win.iso", Age = 30 }, new { Name = "win (1).iso", Age = 5 }, new { Name = "win (2).iso.crdownload", Age = 1 }, new { Name = "winx.iso", Age = 0 },
        };
        var o = Same(c);
        Assert.Equal([@"Find;Value=<root>\downloads\win (1).iso", "Find;Value="], o.Results);
    }
}

// DownloadFakes: IsoShared.cs
