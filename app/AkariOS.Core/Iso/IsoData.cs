using System.Globalization;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using static AkariOS.Core.Data.PsSemantics;

namespace AkariOS.Core.Iso;

/// <summary>A problem the ISO Builder stops on, with a message for the user.</summary>
public sealed class IsoException(string message) : Exception(message);

/// <summary>
/// One of zISO's ten options (src/Core/Iso/Data/Options/&lt;Id&gt;.psd1): its page text, Group (Update, Security,
/// Apps) and Order, the options it rules out, and what it does to the image: registry rows, paths and keys removed,
/// features and apps matched by pattern.
/// </summary>
public sealed record IsoOption(string Id, string Name, string Description, string Group, int Order, IReadOnlyList<string> Excludes,
    IReadOnlyList<PsHashtable> Registry, IReadOnlyList<string> Remove, IReadOnlyList<string> RemoveKeys, IReadOnlyList<string> Features,
    IReadOnlyList<string> Apps);

/// <summary>zISO's always-on settings (Always.psd1): the requirement bypass (install.wim and boot.wim), boot.wim's
/// own row, the install image's rows and paths removed.</summary>
public sealed record IsoAlways(IReadOnlyList<PsHashtable> Requirements, IReadOnlyList<PsHashtable> Boot, IReadOnlyList<PsHashtable> Registry, IReadOnlyList<string> Remove);

/// <summary>A data row on the loaded hives: the registry row (its Path under <see cref="IsoData.HiveRoot"/>), its
/// hive, and whether it is written as TrustedInstaller.</summary>
public sealed record IsoRow(string Hive, RegistryRow Row, bool Trusted);

/// <summary>The ISO Builder's data and the pure helpers over it (src/Core/Iso.ps1, Iso/Image.ps1).</summary>
public static class IsoData
{
    public const string Folder = "src/Core/Iso/Data/";

    /// <summary>The image's hives: name → file under the mounted image ($AkariIsoHives, in load order).</summary>
    public static readonly IReadOnlyList<(string Name, string File)> Hives =
    [
        ("SOFTWARE", @"Windows\System32\config\SOFTWARE"), ("SYSTEM", @"Windows\System32\config\SYSTEM"),
        ("DEFAULT", @"Windows\System32\config\DEFAULT"), ("NTUSER", @"Users\Default\NTUSER.DAT"),
    ];

    /// <summary>Where the loaded hives are: HKLM\AkariIso_&lt;hive&gt;.</summary>
    public const string HiveRoot = @"HKLM:\AkariIso_";

    public static readonly string[] Groups = ["Update", "Security", "Apps"];

    /// <summary>Every option, in page order (Group, then Order).</summary>
    public static IReadOnlyList<IsoOption> Options(ISourceFiles files) =>
        [.. files.List(Folder + "Options/").Where(p => p.EndsWith(".psd1", StringComparison.OrdinalIgnoreCase))
            .Select(p => Option(Path.GetFileNameWithoutExtension(p), (PsHashtable)PsData.Parse(files.ReadText(p)).Value!))
            .OrderBy(o => Array.IndexOf(Groups, o.Group)).ThenBy(o => o.Order)];

    private static IsoOption Option(string id, PsHashtable h) => new(id, Text(h.Get("Name")) ?? "", Text(h.Get("Description")) ?? "",
        Text(h.Get("Group")) ?? "", Convert.ToInt32(h.Get("Order") ?? 0, CultureInfo.InvariantCulture), Strings(h.Get("Excludes")),
        Tables(h.Get("Registry")), Strings(h.Get("Remove")), Strings(h.Get("RemoveKeys")), Strings(h.Get("Features")), Strings(h.Get("Apps")));

    public static IsoAlways Always(ISourceFiles files)
    {
        var h = (PsHashtable)PsData.Parse(files.ReadText(Folder + "Always.psd1")).Value!;
        return new IsoAlways(Tables(h.Get("Requirements")), Tables(h.Get("Boot")), Tables(h.Get("Registry")), Strings(h.Get("Remove")));
    }

    private static IReadOnlyList<string> Strings(object? v) => [.. AsList(v).Where(Truthy).Select(x => Text(x)!)];
    private static IReadOnlyList<PsHashtable> Tables(object? v) => [.. AsList(v).OfType<PsHashtable>()];

    /// <summary>A message when the picked ids don't go together (an unknown id, or two that exclude each other), else
    /// null (Test-AkariIsoOptions).</summary>
    public static string? Check(IEnumerable<string> ids, IReadOnlyList<IsoOption> options)
    {
        var picked = ids.Where(i => i.Length > 0).ToList();
        foreach (var id in picked)
        {
            var o = Find(options, id);
            if (o == null) return $"Unknown ISO option: {id}";
            foreach (var x in o.Excludes)
                if (picked.Contains(x, StringComparer.OrdinalIgnoreCase)) return $"'{o.Name}' and '{Find(options, x)?.Name}' can't be picked together.";
        }
        return null;
    }

    private static IsoOption? Find(IReadOnlyList<IsoOption> options, string id) => options.FirstOrDefault(o => o.Id.Equals(id, StringComparison.OrdinalIgnoreCase));

    /// <summary>The picked options, in page order (Get-AkariIsoPicked).</summary>
    public static IReadOnlyList<IsoOption> Picked(IEnumerable<string>? ids, IReadOnlyList<IsoOption> options)
    {
        var set = (ids ?? []).ToHashSet(StringComparer.OrdinalIgnoreCase);
        return [.. options.Where(o => set.Contains(o.Id))];
    }

    /// <summary>The options a picked one rules out (Get-AkariIsoBlocked: sorted, once each).</summary>
    public static IReadOnlyList<string> Blocked(IEnumerable<string> ids, IReadOnlyList<IsoOption> options) =>
        [.. Picked(ids, options).SelectMany(o => o.Excludes).Order(StringComparer.CurrentCultureIgnoreCase).Distinct(StringComparer.CurrentCultureIgnoreCase)];

    /// <summary>Several "hide:" lists for Settings' SettingsPageVisibility (Defender's, AI's) become one row, or the
    /// last would win (Merge-AkariIsoRows).</summary>
    public static IReadOnlyList<PsHashtable> Merge(IEnumerable<PsHashtable> rows)
    {
        var output = new List<PsHashtable>();
        var parts = new List<string>();
        var at = -1;
        foreach (var r in rows)
        {
            var value = Text(r.Get("Value")) ?? "";
            if (string.Equals(Text(r.Get("Name")), "SettingsPageVisibility", StringComparison.OrdinalIgnoreCase) && Like(value, "hide:*"))
            {
                foreach (var p in value[5..].Split(';')) if (p.Length > 0 && !parts.Contains(p)) parts.Add(p);
                if (at < 0) { at = output.Count; output.Add(r); }
                continue;
            }
            output.Add(r);
        }
        if (at >= 0) output[at] = output[at].With("Value", "hide:" + string.Join(";", parts) + ";");
        return output;
    }

    /// <summary>Data rows ('SOFTWARE\...') as registry rows under the loaded hives (ConvertTo-AkariIsoRows): a binary
    /// value's hex text as bytes; a hive the build doesn't load throws.</summary>
    public static IReadOnlyList<IsoRow> Rows(IEnumerable<PsHashtable> rows, string root) => [.. rows.Select(r =>
    {
        var path = Text(r.Get("Path")) ?? "";
        var cut = path.IndexOf('\\');
        var hive = cut < 0 ? path : path[..cut];
        if (!Hives.Any(h => h.Name.Equals(hive, StringComparison.OrdinalIgnoreCase))) throw new IsoException($"Unknown hive in ISO row: {path}");
        var row = Loader.ToRow(r)!;
        var value = row.Value;
        if (string.Equals(row.Type, "Binary", StringComparison.OrdinalIgnoreCase) && value is string hex) value = FromHex(hex);
        return new IsoRow(hive, row with { Path = $"{root}{hive}\\{(cut < 0 ? "" : path[(cut + 1)..])}", Value = value }, Truthy(r.Get("Trusted")));
    })];

    /// <summary>ConvertFrom-AkariHex: 'ab,01' → bytes.</summary>
    public static byte[] FromHex(string hex) =>
        hex.Length == 0 ? [] : [.. hex.Split(',').Select(h => byte.Parse(h.Trim(), NumberStyles.HexNumber, CultureInfo.InvariantCulture))];

    /// <summary>The names to remove: the user's picks plus what on the image matches an option's patterns, once each
    /// (Resolve-AkariIsoNames).</summary>
    public static IReadOnlyList<string> Resolve(IEnumerable<string> picked, IEnumerable<string> patterns, IEnumerable<string> available)
    {
        var set = new List<string>();
        foreach (var n in picked) if (n.Length > 0 && !set.Contains(n)) set.Add(n);
        foreach (var p in patterns)
            foreach (var n in available)
                if (Like(n, p) && !set.Contains(n)) set.Add(n);
        return set;
    }

    /// <summary>'Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe' → 'Microsoft.BingNews_8wekyb3d8bbwe'.</summary>
    public static string Family(string package)
    {
        var p = package.Split('_');
        return $"{p[0]}_{p[^1]}";
    }
}
