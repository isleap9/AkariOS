using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using static AkariOS.Core.Data.PsSemantics;

namespace AkariOS.Core.Iso;

/// <summary>One of Massgrave's Windows 11 x64 ISOs: its product, language, file name and download page.</summary>
public sealed record MassgraveIso(string Product, string Language, string File, string Url);

/// <summary>Massgrave (massgrave.dev): what UUP Dump can't make. Its hosts block scripts, so Akari only lists the
/// files (read from the site's markdown on GitHub) and finds the one the browser downloaded (src/Core/IsoDownload.ps1).</summary>
public static partial class Massgrave
{
    public static readonly string[] Pages =
    [
        "https://raw.githubusercontent.com/massgravel/massgrave.dev/main/docs/windows_11_links.md",
        "https://raw.githubusercontent.com/massgravel/massgrave.dev/main/docs/windows_ltsc_links.md",
    ];

    /// <summary>A download page's Windows 11 x64 ISOs; the product is the last bold line naming Windows before the
    /// table (Read-AkariMassgrave).</summary>
    public static IReadOnlyList<MassgraveIso> Read(string markdown)
    {
        var product = "";
        var list = new List<MassgraveIso>();
        foreach (var l in NewLine().Split(markdown))
        {
            if (Bold().Match(l) is { Success: true } b) { product = b.Groups[1].Value.Trim(); continue; }
            if (Row().Match(l) is not { Success: true } m) continue;
            if (!m.Groups[2].Value.Equals("x64", StringComparison.OrdinalIgnoreCase) || !m.Groups[3].Value.Contains("windows_11", StringComparison.OrdinalIgnoreCase)) continue;
            list.Add(new MassgraveIso(product, m.Groups[1].Value, m.Groups[3].Value, m.Groups[4].Value));
        }
        return list;
    }

    /// <summary>The products in page order, once each.</summary>
    public static IReadOnlyList<string> Products(IEnumerable<MassgraveIso> items) => [.. items.Select(i => i.Product).Distinct(StringComparer.Ordinal)];

    /// <summary>A product's files (its languages).</summary>
    public static IReadOnlyList<MassgraveIso> Files(IEnumerable<MassgraveIso> items, string product) =>
        [.. items.Where(i => i.Product.Equals(product, StringComparison.OrdinalIgnoreCase))];

    [GeneratedRegex("\r?\n")]
    private static partial Regex NewLine();

    [GeneratedRegex(@"^\*\*(Windows[^*]*)\*\*", RegexOptions.IgnoreCase)]
    private static partial Regex Bold();

    [GeneratedRegex(@"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*\[([^\]]+\.iso)\]\((https?://[^)\s]+)\)", RegexOptions.IgnoreCase)]
    private static partial Regex Row();
}

/// <summary>A UUP Dump build: its id, title, build number, architecture.</summary>
public sealed record UupBuild(string Id, string Title, string Build, string Arch);

/// <summary>An edition UUP Dump's converter can make: its label, the edition code, and the virtual edition made from
/// it ('' = the edition itself).</summary>
public sealed record UupTarget(string Label, string Code, string Virtual);

/// <summary>UUP Dump's pure parts (src/Core/IsoDownload.ps1): its answers read, the edition list, the converter's
/// package request and settings, the ISO's name.</summary>
public static partial class Uup
{
    /// <summary>Version → its build number ($AkariUupVersions, newest first).</summary>
    public static readonly IReadOnlyList<(string Version, string Build)> Versions = [("26H2", "26300"), ("25H2", "26200"), ("24H2", "26100"), ("23H2", "22631")];

    /// <summary>Virtual editions the converter makes from Pro: code → label ($AkariUupVirtual).</summary>
    public static readonly IReadOnlyList<(string Code, string Label)> Virtual =
    [
        ("Enterprise", "Enterprise"), ("Education", "Education"), ("IoTEnterprise", "IoT Enterprise"),
        ("ProfessionalEducation", "Pro Education"), ("ProfessionalWorkstation", "Pro for Workstations"),
    ];

    /// <summary>The builds of a listid answer: an object keyed by number, or an array (ConvertTo-AkariUupBuilds).</summary>
    public static IReadOnlyList<UupBuild> Builds(JsonElement builds)
    {
        IEnumerable<JsonElement> items = builds.ValueKind switch
        {
            JsonValueKind.Array => builds.EnumerateArray(),
            JsonValueKind.Object => builds.EnumerateObject().Select(p => p.Value),
            _ => [],
        };
        return [.. items.Select(b => new UupBuild(Field(b, "uuid"), Field(b, "title"), Field(b, "build"), Field(b, "arch")))];
    }

    /// <summary>A JSON field as PowerShell's "$(...)" writes it ('' when missing).</summary>
    public static string Field(JsonElement o, string name) =>
        o.ValueKind == JsonValueKind.Object && o.TryGetProperty(name, out var v) ? v.ValueKind switch
        {
            JsonValueKind.String => v.GetString()!,
            JsonValueKind.Null or JsonValueKind.Undefined => "",
            JsonValueKind.True => "True",
            JsonValueKind.False => "False",
            _ => v.GetRawText(),
        } : "";

    /// <summary>The newest release (not a preview, not a lone update) of a build number, amd64 (Select-AkariUupBuild).</summary>
    public static UupBuild? Select(IEnumerable<UupBuild> builds, string number) => builds
        .Where(b => Release().IsMatch(b.Title) && !Preview().IsMatch(b.Title) && Like(b.Build, number + ".*")
            && (b.Arch.Length == 0 || b.Arch.Equals("amd64", StringComparison.OrdinalIgnoreCase)))
        .OrderByDescending(b => Version.Parse("10.0." + b.Build))
        .FirstOrDefault();

    [GeneratedRegex("^Windows 11, version", RegexOptions.IgnoreCase)]
    private static partial Regex Release();

    [GeneratedRegex("preview", RegexOptions.IgnoreCase)]
    private static partial Regex Preview();

    /// <summary>The editions a build and language can become: its own (Home, Pro, their N first) and, with Pro, the
    /// virtual ones (Get-AkariUupTargets). <paramref name="fancy"/>: the API's editionFancyNames (code → name).</summary>
    public static IReadOnlyList<UupTarget> Targets(JsonElement fancy)
    {
        var codes = fancy.ValueKind == JsonValueKind.Object ? fancy.EnumerateObject().Select(p => p.Name).ToList() : [];
        var output = new List<UupTarget>();
        foreach (var c in new[] { "CORE", "COREN", "PROFESSIONAL", "PROFESSIONALN" }.Concat(codes.Order(StringComparer.CurrentCultureIgnoreCase)))
        {
            if (!codes.Contains(c, StringComparer.OrdinalIgnoreCase) || output.Any(t => t.Code.Equals(c, StringComparison.OrdinalIgnoreCase) && t.Virtual.Length == 0)) continue;
            var label = c.ToUpperInvariant() switch
            {
                "CORE" => "Home",
                "COREN" => "Home N",
                "PROFESSIONAL" => "Pro",
                "PROFESSIONALN" => "Pro N",
                _ => WindowsPrefix().Replace(Field(fancy, codes.First(x => x.Equals(c, StringComparison.OrdinalIgnoreCase))), ""),
            };
            output.Add(new UupTarget(label, c, ""));
        }
        if (codes.Contains("PROFESSIONAL", StringComparer.OrdinalIgnoreCase))
            output.AddRange(Virtual.Select(v => new UupTarget(v.Label, "PROFESSIONAL", v.Code)));
        return output;
    }

    [GeneratedRegex("^Windows ", RegexOptions.IgnoreCase)]
    private static partial Regex WindowsPrefix();

    /// <summary>The converter package request: an edition as it is, or a virtual one made from it (zISO's bodies).</summary>
    public static IReadOnlyDictionary<string, string> PackageBody(string? virtualEdition) => string.IsNullOrEmpty(virtualEdition)
        ? new Dictionary<string, string> { ["autodl"] = "2", ["updates"] = "1", ["cleanup"] = "1" }
        : new Dictionary<string, string> { ["autodl"] = "3", ["updates"] = "1", ["cleanup"] = "1", ["virtualEditions[]"] = virtualEdition };

    /// <summary>ConvertConfig.ini as zISO sets it: exit when done, reset the component base, .NET 3.5 in; a virtual
    /// edition made and the source edition dropped (Set-AkariUupConfig).</summary>
    public static IReadOnlyList<string> Config(IEnumerable<string> lines, string? virtualEdition)
    {
        var set = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) { ["AutoExit"] = "1", ["ResetBase"] = "1", ["NetFx3"] = "1" };
        if (!string.IsNullOrEmpty(virtualEdition))
        {
            set["StartVirtual"] = "1";
            set["vDeleteSource"] = "1";
            set["vAutoEditions"] = virtualEdition;
        }
        return [.. lines.Select(l =>
        {
            var k = l.Split('=', 2)[0].Trim();
            return Setting().IsMatch(l) && set.TryGetValue(k, out var v) ? $"{k}={v}" : l;
        })];
    }

    [GeneratedRegex(@"^\s*[^;\[][^=]*=", RegexOptions.IgnoreCase)]
    private static partial Regex Setting();

    /// <summary>The ISO's name: Windows11_25H2_IoT-Enterprise_en-us.iso.</summary>
    public static string IsoName(string version, string label, string lang) =>
        string.Format(CultureInfo.InvariantCulture, "Windows11_{0}_{1}_{2}.iso", version, NonAlnum().Replace(label, "-"), lang);

    [GeneratedRegex("[^A-Za-z0-9]+", RegexOptions.IgnoreCase)]
    private static partial Regex NonAlnum();
}
