using System.Text.Json;
using AkariOS.Core.Iso;
using AkariOS.Core.Sources;
using AkariOS.Core.Unattend;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native ISO Builder's pure parts against the PowerShell app's (Oracle/Export-Iso.ps1): the options and every row
/// the build writes, the checks, the plan, the oscdimg arguments, the space check, the editions, the page's helpers,
/// Massgrave's catalogue and UUP Dump's builds, editions and converter settings.
/// </summary>
public sealed class IsoOracleTests
{
    private static readonly ISourceFiles Files = new EmbeddedSourceFiles();
    private static readonly string Temp = Path.Combine(Path.GetTempPath(), $"akari-iso-oracle-{Guid.NewGuid():N}");

    /// <summary>Media folders for the oscdimg cases: both boot files, UEFI only, none.</summary>
    private static readonly string[] Media = MakeMedia();

    private static string[] MakeMedia()
    {
        string Folder(string name, params string[] files)
        {
            var d = Path.Combine(Temp, name);
            foreach (var f in files)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(Path.Combine(d, f))!);
                File.WriteAllText(Path.Combine(d, f), "x");
            }
            Directory.CreateDirectory(d);
            return d;
        }
        return [Folder("both", @"boot\etfsboot.com", @"efi\microsoft\boot\efisys.bin"), Folder("uefi", @"efi\microsoft\boot\efisys.bin"), Folder("none")];
    }

    private static readonly string[][] Checks =
    [
        [], ["DisableUpdates"], ["SecurityOnly", "DisableVersionUpgrade"], ["RemoveAI"], ["DisableUpdates", "SecurityOnly"],
        ["Nope"], ["RemoveDefender", "RemoveEdge", "RemoveOneDrive", "DisableTelemetry"],
    ];

    private static readonly object[] Plans =
    [
        new { Edition = "Windows 11 Pro" },
        new { Edition = "Windows 11 Home", Apps = new[] { "a" }, Features = new[] { "f" }, Capabilities = new[] { "c" }, Packages = new[] { "p" }, AkariDir = @"C:\AkariOS", Unattend = "AQ==" },
        new { Edition = "Pro", Options = new[] { "RemoveDefender" } },
        new { Edition = "Pro", Options = new[] { "RemoveAI", "DisableTelemetry" }, Apps = new[] { "" } },
    ];

    private static readonly object[] Resolve =
    [
        new { Picked = new[] { "A", "B", "A" }, Patterns = new[] { "Media*", "*Recall*" }, Available = new[] { "MediaPlayback", "Recall", "B", "Other" } },
        new { Picked = Array.Empty<string>(), Patterns = Array.Empty<string>(), Available = new[] { "x" } },
    ];

    private static readonly string[] Families = ["Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe", "Clipchamp.Clipchamp_2.2.8.0_neutral_~_yxz26nhyzhsrt", "single"];
    private static readonly string[] OutNames = [@"D:\isos\Win11_25H2_English_x64.iso", "", @"C:\a.b\name.with.dots.iso"];
    private static readonly object[] Space =
    [
        new { Free = 30L << 30, Format = "NTFS" }, new { Free = 60L << 30, Format = "FAT32" }, new { Free = (long)(10.56 * (1L << 30)), Format = "NTFS" },
    ];

    private static readonly object[][] Editions =
    [
        [new { Index = 1, Name = "Windows 11 Home", Version = "10.0.26100.1742" }, new { Index = 6, Name = "Windows 11 Pro", Version = "10.0.26100.1742" }],
        [new { Index = 1, Name = "Windows 10 Pro", Version = "10.0.19045.2965" }, new { Index = 2, Name = "Odd", Version = "10.0" }, new { Index = 3, Name = "Bad", Version = "x" }],
    ];

    private static readonly object[][] Answers = [["Gamer", "pw", true], ["Gamer", "pw", false], ["  ", "", true]];

    private static readonly object[] Recommended =
    [
        new
        {
            Tweaks = new object[]
            {
                new { Id = "appx/Microsoft.BingNews", Risk = "Safe" }, new { Id = "appx/Microsoft.WindowsCalculator", Risk = "Safe", Keep = true },
                new { Id = "appx/Microsoft.XboxApp", Risk = "Caution" }, new { Id = "other/Microsoft.Unknown", Risk = "Safe" },
            },
            Apps = new object[]
            {
                new { Name = "Microsoft.BingNews", Package = "news" }, new { Name = "Microsoft.WindowsCalculator", Package = "calc" },
                new { Name = "Microsoft.XboxApp", Package = "xbox" }, new { Name = "Microsoft.Unknown", Package = "u" }, new { Name = "microsoft.bingnews", Package = "news2" },
            },
        },
    ];

    private static readonly object[] UupBuilds =
    [
        new
        {
            Number = "26100",
            Builds = (object)new Dictionary<string, object>
            {
                ["0"] = new { uuid = "kb", build = "26100.9544", title = "Critical OOBE Update for Windows 11 - KB5128942 (26100.9544)", arch = "amd64" },
                ["1"] = new { uuid = "old", build = "26100.9711", title = "Windows 11, version 24H2 (26100.9711)", arch = "amd64" },
                ["2"] = new { uuid = "new", build = "26100.9725", title = "Windows 11, version 24H2 (26100.9725)", arch = "amd64" },
                ["3"] = new { uuid = "pre", build = "26100.9999", title = "Windows 11 Insider Preview 26100.9999", arch = "amd64" },
                ["4"] = new { uuid = "arm", build = "26100.9800", title = "Windows 11, version 24H2 (26100.9800)", arch = "arm64" },
                ["5"] = new { uuid = "big", build = "26100.10001", title = "windows 11, Version 24H2 (26100.10001)", arch = "" },
            },
        },
        new { Number = "26200", Builds = (object)new object[] { new { uuid = "a", build = 26200.7, title = "Windows 11, version 25H2 (26200.7)", arch = "amd64" } } },
        new { Number = "22631", Builds = (object?)null },
    ];

    private static readonly object[] UupTargets =
    [
        new Dictionary<string, string>
        {
            ["PROFESSIONALN"] = "Windows Pro N", ["CORE"] = "Windows Home", ["ENTERPRISE"] = "Windows Enterprise", ["PROFESSIONAL"] = "Windows Pro",
            ["COREN"] = "Windows Home N", ["CLOUD"] = "Windows SE",
        },
        new Dictionary<string, string> { ["CORE"] = "Windows Home", ["COREN"] = "Windows Home N" },
    ];

    private static readonly string[] UupVirtual = ["", "IoTEnterprise"];
    private static readonly string[] UupConfig =
    [
        "[convert-UUP]", "AutoStart    =1", "AddUpdates   =1", "ResetBase    =0", "NetFx3       =0", "; NetFx3=0 comment", "  AutoExit = 0",
        "[create_virtual_editions]", "vAutoStart   =1", "vDeleteSource=0", "vAutoEditions=Enterprise", "StartVirtual =0", "no equals here",
    ];
    private static readonly string[][] UupNames = [["25H2", "IoT Enterprise", "en-us"], ["24H2", "Pro for Workstations", "it-it"], ["23H2", "Home N", "de-de"]];

    private static readonly Lazy<JsonElement> Ps = new(() =>
    {
        Directory.CreateDirectory(Temp);
        var cases = Path.Combine(Temp, "cases.json");
        File.WriteAllText(cases, JsonSerializer.Serialize(new
        {
            Checks, Plans, Resolve, Families, OutNames, Oscdimg = Media, Space, Editions, Answers, Recommended,
            Massgrave = Path.Combine(Repo.Root, "tests", "Fixtures", "Massgrave", "sample.md"),
            UupBuilds, UupTargets, UupVirtual, UupConfig, UupNames,
        }));
        try { return Oracle.Run("Export-Iso.ps1", "-Src", Repo.Src, "-Cases", cases); }
        finally { File.Delete(cases); }
    });

    private static JsonElement P(string name) => Ps.Value.GetProperty(name);
    private static string[] Texts(JsonElement e) => e.ValueKind == JsonValueKind.Array ? [.. e.EnumerateArray().Select(x => x.GetString() ?? "")] : [e.GetString() ?? ""];
    private static T Json<T>(object o) => JsonSerializer.Deserialize<T>(JsonSerializer.Serialize(o))!;

    private static string Show(object? v) => v switch
    {
        null => "null",
        byte[] b => "hex:" + Convert.ToHexString(b).ToLowerInvariant(),
        bool x => x ? "True" : "False",
        _ => Convert.ToString(v, System.Globalization.CultureInfo.InvariantCulture) ?? "",
    };

    private static string[] Rows(JsonElement rows) =>
        [.. rows.EnumerateArray().Select(r => $"{r.GetProperty("Path").GetString()}|{r.GetProperty("Name").GetString() ?? "<key>"}|{r.GetProperty("Type").GetString()}|{r.GetProperty("Value").GetString()}|{r.GetProperty("Trusted").GetBoolean()}|{r.GetProperty("Hive").GetString()}")];

    private static string[] Rows(IEnumerable<IsoRow> rows) =>
        [.. rows.Select(r => $"{r.Row.Path}|{(r.Row.IsKeyRow ? "<key>" : r.Row.Name)}|{r.Row.Type}|{Show(r.Row.Value)}|{r.Trusted}|{r.Hive}")];

    private static readonly IReadOnlyList<IsoOption> Options = IsoData.Options(Files);

    [Fact]
    public void The_options_are_the_same_in_page_order_with_the_same_rows()
    {
        var ps = P("Options").EnumerateArray().ToList();
        Assert.Equal(ps.Select(o => o.GetProperty("Id").GetString()), Options.Select(o => o.Id));
        foreach (var (o, j) in Options.Zip(ps))
        {
            Assert.Equal($"{j.GetProperty("Name").GetString()}|{j.GetProperty("Description").GetString()}|{j.GetProperty("Group").GetString()}|{j.GetProperty("Order").GetInt32()}",
                $"{o.Name}|{o.Description}|{o.Group}|{o.Order}");
            Assert.Equal(Texts(j.GetProperty("Excludes")), o.Excludes);
            Assert.Equal(Texts(j.GetProperty("Remove")), o.Remove);
            Assert.Equal(Texts(j.GetProperty("RemoveKeys")), o.RemoveKeys);
            Assert.Equal(Texts(j.GetProperty("Features")), o.Features);
            Assert.Equal(Texts(j.GetProperty("Apps")), o.Apps);
            Assert.Equal(Rows(j.GetProperty("Rows")), Rows(IsoData.Rows(IsoData.Merge(o.Registry), IsoData.HiveRoot)));
        }
    }

    [Fact]
    public void The_always_on_rows_and_every_row_merged_are_the_same()
    {
        var a = IsoData.Always(Files);
        var j = P("Always");
        Assert.Equal(Rows(j.GetProperty("Requirements")), Rows(IsoData.Rows(a.Requirements, IsoData.HiveRoot)));
        Assert.Equal(Rows(j.GetProperty("Boot")), Rows(IsoData.Rows(a.Boot, IsoData.HiveRoot)));
        Assert.Equal(Rows(j.GetProperty("Registry")), Rows(IsoData.Rows(IsoData.Merge(a.Registry), IsoData.HiveRoot)));
        Assert.Equal(Texts(j.GetProperty("Remove")), a.Remove);
        var all = a.Requirements.Concat(a.Registry).Concat(Options.SelectMany(o => o.Registry));
        Assert.Equal(Rows(P("MergedAll")), Rows(IsoData.Rows(IsoData.Merge(all), IsoData.HiveRoot)));
    }

    [Fact]
    public void Options_that_don_t_go_together_and_the_ones_a_pick_rules_out_are_the_same()
    {
        var checks = P("Checks").EnumerateArray().ToList();
        var blocked = P("Blocked").EnumerateArray().ToList();
        for (var i = 0; i < Checks.Length; i++)
        {
            Assert.Equal(checks[i].GetString(), IsoData.Check(Checks[i], Options) ?? "");
            Assert.Equal(Texts(blocked[i]), IsoData.Blocked(Checks[i], Options));
        }
    }

    [Fact]
    public void The_plans_are_the_same()
    {
        var ps = P("Plans").EnumerateArray().ToList();
        for (var i = 0; i < Plans.Length; i++)
        {
            var ch = Json<IsoChoices>(Plans[i]);
            Assert.Equal(Texts(ps[i]), IsoPlan.Steps(ch, IsoData.Picked(ch.Options, Options)).Select(s => $"{s.Id}|{s.Text}"));
        }
    }

    [Fact]
    public void Names_families_and_file_names_are_the_same()
    {
        var resolve = P("Resolve").EnumerateArray().ToList();
        for (var i = 0; i < Resolve.Length; i++)
        {
            var r = Json<Dictionary<string, string[]>>(Resolve[i]);
            Assert.Equal(Texts(resolve[i]), IsoData.Resolve(r["Picked"], r["Patterns"], r["Available"]));
        }
        Assert.Equal(Texts(P("Families")), Families.Select(IsoData.Family));
        Assert.Equal(Texts(P("OutNames")), OutNames.Select(IsoPlan.OutName));
    }

    [Fact]
    public void Oscdimg_s_arguments_the_space_check_and_the_editions_are_the_same()
    {
        var osc = Texts(P("Oscdimg"));
        try
        {
            for (var i = 0; i < Media.Length; i++)
            {
                string ours;
                try { ours = string.Join("|", IsoPlan.OscdimgArgs(Media[i], @"D:\out.iso", File.Exists)); }
                catch (IsoException e) { ours = "error:" + e.Message; }
                Assert.Equal(osc[i], ours);
            }
        }
        finally { Directory.Delete(Temp, true); }
        var space = Texts(P("Space"));
        for (var i = 0; i < Space.Length; i++)
        {
            var s = Json<Dictionary<string, JsonElement>>(Space[i]);
            Assert.Equal(space[i], IsoPlan.Space(s["Free"].GetInt64(), s["Format"].GetString()!) ?? "");
        }
        var eds = P("Editions").EnumerateArray().ToList();
        for (var i = 0; i < Editions.Length; i++)
        {
            var images = Json<WimImage[]>(Editions[i]);
            Assert.Equal(Texts(eds[i]), IsoPlan.Editions(images).Select(e => $"{e.Index}|{e.Name}|{e.Version}|{e.Supported}"));
        }
    }

    [Fact]
    public void The_page_s_helpers_are_the_same()
    {
        var start = UnattendFields.New();
        foreach (var (k, v) in (Data.PsHashtable)UnattendStart.Spec(Files).Get("Defaults")!) start[k] = [Data.PsSemantics.Text(v) ?? ""];
        var answers = P("Answers").EnumerateArray().ToList();
        for (var i = 0; i < Answers.Length; i++)
        {
            var f = IsoPlan.AnswerFields(start, (string)Answers[i][0], (string)Answers[i][1], (bool)Answers[i][2]);
            var ps = answers[i].EnumerateObject().ToDictionary(p => p.Name, p => p.Value.GetString());
            Assert.Equal(ps.Keys.Order(StringComparer.OrdinalIgnoreCase), f.Keys.Order(StringComparer.OrdinalIgnoreCase));
            foreach (var (k, v) in ps) Assert.Equal($"{k}={v}", $"{k}={string.Join(" ", f[k])}");
        }
        var rec = P("Recommended").EnumerateArray().ToList();
        for (var i = 0; i < Recommended.Length; i++)
        {
            var r = Json<RecommendedCase>(Recommended[i]);
            Assert.Equal(Texts(rec[i]), IsoPlan.Recommended(r.Apps, r.Tweaks.Select(t => (t.Id, t.Risk, t.Keep))));
        }
    }

    private sealed record RecommendedCase(RecTweak[] Tweaks, ImageApp[] Apps);
    private sealed record RecTweak(string Id, string? Risk, bool Keep);

    [Fact]
    public void Massgrave_s_catalogue_is_read_the_same()
    {
        var items = Massgrave.Read(File.ReadAllText(Path.Combine(Repo.Root, "tests", "Fixtures", "Massgrave", "sample.md")));
        Assert.Equal(Texts(P("Massgrave")), items.Select(i => $"{i.Product}|{i.Language}|{i.File}|{i.Url}"));
        Assert.Equal(Texts(P("MassgraveProducts")), Massgrave.Products(items));
        Assert.Equal(P("MassgraveFiles").EnumerateArray().Select(Texts).Select(x => string.Join(",", x)),
            Massgrave.Products(items).Select(p => string.Join(",", Massgrave.Files(items, p).Select(f => f.Language))));
    }

    [Fact]
    public void UUP_Dump_s_builds_editions_and_converter_settings_are_the_same()
    {
        var builds = P("UupBuilds").EnumerateArray().ToList();
        for (var i = 0; i < UupBuilds.Length; i++)
        {
            var c = JsonSerializer.SerializeToElement(UupBuilds[i]);
            var list = Uup.Builds(c.GetProperty("Builds"));
            Assert.Equal(Texts(builds[i].GetProperty("All")), list.Select(b => $"{b.Id}|{b.Title}|{b.Build}|{b.Arch}"));
            Assert.Equal(builds[i].GetProperty("Pick").GetString(), Uup.Select(list, c.GetProperty("Number").GetString()!)?.Id ?? "");
        }
        var targets = P("UupTargets").EnumerateArray().ToList();
        for (var i = 0; i < UupTargets.Length; i++)
            Assert.Equal(Texts(targets[i]), Uup.Targets(JsonSerializer.SerializeToElement(UupTargets[i])).Select(t => $"{t.Label}|{t.Code}|{t.Virtual}"));
        Assert.Equal(Texts(P("UupBodies")), UupVirtual.Select(v => string.Join("&", Uup.PackageBody(v).OrderBy(p => p.Key, StringComparer.CurrentCultureIgnoreCase).Select(p => $"{p.Key}={p.Value}"))));
        var configs = P("UupConfigs").EnumerateArray().ToList();
        for (var i = 0; i < UupVirtual.Length; i++) Assert.Equal(Texts(configs[i]), Uup.Config(UupConfig, UupVirtual[i]));
        Assert.Equal(Texts(P("UupNames")), UupNames.Select(n => Uup.IsoName(n[0], n[1], n[2])));
    }
}
