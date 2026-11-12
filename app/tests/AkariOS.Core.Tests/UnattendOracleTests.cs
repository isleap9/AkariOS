using System.Text.Json;
using AkariOS.Core.Unattend;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native Unattend Generator against src\Core\Unattend.ps1 on the same choices (Oracle/Export-Unattend.ps1): every
/// fixture made on Schneegans' site, the form's Defaults, the ISO Builder's local account fields and his checks. The
/// fields, the bookmark query and the file's bytes must be the same.
/// </summary>
public sealed class UnattendOracleTests
{
    private static string Fixtures => Path.Combine(Repo.Root, "tests", "Fixtures", "Unattend");

    public static readonly string[] FixtureNames = Directory.GetFiles(Fixtures, "*.xml")
        .Select(f => Path.GetFileNameWithoutExtension(f)).Order(StringComparer.Ordinal).ToArray();

    /// <summary>Pester's "his checks" (tests\Unattend.Tests.ps1), on 2-unattended's fields (before Cases: static
    /// fields are set in order).</summary>
    private static readonly (string Name, Dictionary<string, object> Change)[] Checks =
    [
        ("check-computer-name", new() { ["ComputerName"] = "12345" }),
        ("check-user-name", new() { ["AccountName1"] = "guest" }),
        ("check-administrator", new() { ["AccountGroup0"] = "Users" }),
        ("check-name-like-pc", new() { ["AccountName1"] = "gaming-pc" }),
        ("check-name-twice", new() { ["AccountName1"] = "BOSS" }),
        ("check-product-key", new() { ["WindowsEditionMode"] = "Custom", ["ProductKey"] = "ABC" }),
        ("check-auto-logon", new() { ["AutoLogonMode"] = "None" }),
        ("check-diskpart", new() { ["PEMode"] = "Generated", ["PartitionMode"] = "Custom", ["DiskpartScript"] = "SELECT DISK=0\r\nASSIGN LETTER=S" }),
        ("check-no-architecture", new() { ["ProcessorArchitecture"] = Array.Empty<string>() }),
    ];

    /// <summary>This PC's settings the form starts from (Get-AkariUnattendDefaults): known ones, unknown ones, none.</summary>
    private static readonly (string Name, PcRegion Pc)[] Starts =
    [
        ("start-italian", new PcRegion("it-IT", "it-IT", "00000410", "118", "W. Europe Standard Time")),
        ("start-unknown", new PcRegion("xx-XX", "", null, "99999", "Nowhere Standard Time")),
        ("start-none", new PcRegion(null, null, null, null, null)),
    ];

    /// <summary>The cases: (name, the JSON case for the oracle).</summary>
    private static readonly (string Name, object Case)[] Cases =
    [
        .. FixtureNames.Select(n => (n, (object)new { File = Path.Combine(Fixtures, n + ".xml") })),
        ("defaults", new { Defaults = true }),
        ("iso-account", new { Iso = new object[] { "Gamer", "pw", true } }),
        ("iso-setup", new { Iso = new object[] { "Gamer", "pw", false } }),
        ("iso-noname", new { Iso = new object[] { "  ", "", true } }),
        .. Checks.Select(c => (c.Name, (object)new { File = Path.Combine(Fixtures, "2-unattended.xml"), c.Change })),
        .. Starts.Select(s => (s.Name, (object)new { Start = s.Pc })),
    ];

    /// <summary>Messages the native app takes from his library as he wrote them, where the PowerShell port's differ:
    /// case → the port's message turned into his.</summary>
    private static readonly Dictionary<string, Func<string, string>> HisWording = new()
    {
        // his diskpart check quotes the line with typographic quotes
        ["check-diskpart"] = m => m.Replace("'ASSIGN LETTER=W'", "\u2018ASSIGN LETTER=W\u2019").Replace("'W:'", "\u2018W:\u2019"),
    };

    private static readonly string[] Queries =
    [
        "https://schneegans.de/windows/unattend-generator/?a=1&a=2&b=%2D%2Dc+d&&=x&noValue&C=up",
        "https://x/?Name=It%27s%20(ok)!&Multi=a&multi=b&Empty=",
    ];

    private static readonly Lazy<JsonElement> Ps = new(() =>
    {
        var cases = Path.Combine(Path.GetTempPath(), $"akari-unattend-cases-{Guid.NewGuid():N}.json");
        File.WriteAllText(cases, JsonSerializer.Serialize(new { Cases = Cases.Select(c => c.Case).ToArray(), Queries }));
        try { return Oracle.Run("Export-Unattend.ps1", "-Src", Repo.Src, "-Cases", cases); }
        finally { File.Delete(cases); }
    });

    public static TheoryData<string> CaseNames() => [.. Cases.Select(c => c.Name)];

    private static JsonElement Case(string name) => Ps.Value.GetProperty("Cases")[Array.FindIndex(Cases, c => c.Name == name)];

    internal static Dictionary<string, string[]> FieldsOf(JsonElement json)
    {
        var f = UnattendFields.New();
        foreach (var p in json.EnumerateObject()) f[p.Name] = [.. p.Value.EnumerateArray().Select(v => v.GetString()!)];
        return f;
    }

    private static void SameFields(Dictionary<string, string[]> expected, IReadOnlyDictionary<string, string[]> actual)
    {
        Assert.Equal(expected.Keys.Order(StringComparer.OrdinalIgnoreCase), actual.Keys.Order(StringComparer.OrdinalIgnoreCase));
        foreach (var k in expected.Keys) Assert.True(expected[k].SequenceEqual(actual[k]), $"{k}: [{string.Join(",", expected[k])}] vs [{string.Join(",", actual[k])}]");
    }

    [Theory, MemberData(nameof(CaseNames))]
    public void The_query_is_the_same(string name)
    {
        var c = Case(name);
        Assert.Equal(c.GetProperty("Query").GetString(), UnattendQuery.To(FieldsOf(c.GetProperty("Fields"))));
    }

    [Theory, MemberData(nameof(FixtureNamesData))]
    public void A_file_from_his_site_reads_the_same_fields(string name)
    {
        var fields = UnattendQuery.FromXml(File.ReadAllText(Path.Combine(Fixtures, name + ".xml")));
        Assert.NotNull(fields);
        SameFields(FieldsOf(Case(name).GetProperty("Fields")), fields);
    }

    public static TheoryData<string> FixtureNamesData() => [.. FixtureNames];

    [Fact]
    public void A_query_reads_the_same_fields()
    {
        var ps = Ps.Value.GetProperty("Queries");
        for (var i = 0; i < Queries.Length; i++) SameFields(FieldsOf(ps[i]), UnattendQuery.From(Queries[i]));
    }

    [Theory, MemberData(nameof(CaseNames))]
    public void The_file_is_the_same_byte_for_byte(string name)
    {
        var c = Case(name);
        var fields = FieldsOf(c.GetProperty("Fields"));
        var error = c.GetProperty("Error").GetString();
        if (error != "")
        {
            var expected = HisWording.TryGetValue(name, out var his) ? his(error!) : error;
            Assert.Equal(expected, Assert.Throws<UnattendException>(() => UnattendFile.Make(fields)).Message);
            return;
        }
        var ps = Convert.FromBase64String(c.GetProperty("Bytes").GetString()!);
        var ours = UnattendFile.Make(fields);
        Assert.Equal(System.Text.Encoding.ASCII.GetString(ps), System.Text.Encoding.ASCII.GetString(ours));
        Assert.True(ps.SequenceEqual(ours));
    }

    [Theory, MemberData(nameof(FixtureNamesData))]
    public void The_file_matches_his_site(string name)
    {
        var theirs = File.ReadAllText(Path.Combine(Fixtures, name + ".xml"));
        var ours = System.Text.Encoding.ASCII.GetString(UnattendFile.Make(UnattendQuery.FromXml(theirs)!));
        Assert.Equal(Canonical(theirs), Canonical(ours));
    }

    /// <summary>A document without its comment (the bookmark URL: his has the passwords) and his build stamp
    /// (s:Commit; an emptied s:Build), as tests\Unattend.Tests.ps1 compares them.</summary>
    internal static string Canonical(string xml)
    {
        var d = new System.Xml.XmlDocument();
        d.LoadXml(xml);
        var ns = new System.Xml.XmlNamespaceManager(d.NameTable);
        ns.AddNamespace("s", UnattendQuery.Site);
        foreach (var n in d.SelectNodes("//comment()")!.Cast<System.Xml.XmlNode>().ToList()) n.ParentNode!.RemoveChild(n);
        foreach (var n in d.SelectNodes("//s:Commit", ns)!.Cast<System.Xml.XmlNode>().ToList()) n.ParentNode!.RemoveChild(n);
        foreach (var n in d.SelectNodes("//s:Build", ns)!.Cast<System.Xml.XmlNode>().ToList()) if (!n.HasChildNodes) n.ParentNode!.RemoveChild(n);
        return d.OuterXml;
    }

    public static TheoryData<string> StartNames() => [.. Starts.Select(s => s.Name)];

    [Theory, MemberData(nameof(StartNames))]
    public void The_form_starts_from_the_same_fields(string name)
    {
        var pc = Array.Find(Starts, s => s.Name == name).Pc;
        SameStart(FieldsOf(Case(name).GetProperty("Fields")), UnattendStart.Fields(Files, pc));
    }

    [Fact]
    public void The_text_areas_start_from_the_same_samples()
    {
        var ps = Ps.Value.GetProperty("Samples").EnumerateObject().ToDictionary(p => p.Name, p => p.Value.GetString());
        var ours = UnattendStart.Samples(Files);
        Assert.Equal(ps.Keys.Order(), ours.Keys.Order());
        Assert.Equal([], ps.Where(p => Sample(p.Key, p.Value) != Sample(p.Key, ours[p.Key])).Select(p => p.Key));
    }

    /// <summary>A sample as compared: TargetDiskScript without its blank lines (the port leaves an extra one between
    /// the checks; the native app takes his library's sample; pe.cmd drops blank lines either way).</summary>
    private static string? Sample(string key, string? text) =>
        key.Equals("TargetDiskScript", StringComparison.OrdinalIgnoreCase) && text != null
            ? string.Join("\r\n", text.Split("\r\n").Where(l => l.Length > 0))
            : text;

    private static void SameStart(Dictionary<string, string[]> expected, IReadOnlyDictionary<string, string[]> actual)
    {
        Assert.Equal(expected.Keys.Order(StringComparer.OrdinalIgnoreCase), actual.Keys.Order(StringComparer.OrdinalIgnoreCase));
        foreach (var k in expected.Keys)
            Assert.True(expected[k].Select(v => Sample(k, v)).SequenceEqual(actual[k].Select(v => Sample(k, v))), k);
    }

    private static readonly AkariOS.Core.Sources.ISourceFiles Files = new AkariOS.Core.Sources.EmbeddedSourceFiles();

    [Fact]
    public void A_file_made_elsewhere_has_no_fields() =>
        Assert.Null(UnattendQuery.FromXml("<unattend xmlns=\"urn:schemas-microsoft-com:unattend\"/>"));
}
