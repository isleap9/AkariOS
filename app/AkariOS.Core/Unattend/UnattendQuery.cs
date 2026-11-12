using System.Text;
using System.Text.RegularExpressions;

namespace AkariOS.Core.Unattend;

/// <summary>
/// The Unattend Generator's choices: his form's fields (the names and values of
/// https://schneegans.de/windows/unattend-generator/), name → its values (one, or several for a multi-select). Names
/// are case-insensitive, as the PowerShell app's hashtable.
/// </summary>
public static class UnattendFields
{
    public static Dictionary<string, string[]> New() => new(StringComparer.OrdinalIgnoreCase);

    /// <summary>A copy of <paramref name="fields"/> that can be changed.</summary>
    public static Dictionary<string, string[]> Copy(IReadOnlyDictionary<string, string[]> fields)
    {
        var f = New();
        foreach (var (k, v) in fields) f[k] = [.. v];
        return f;
    }

    /// <summary>A field's first value, or <paramref name="fallback"/> when it is missing (Get-AkariUaField).</summary>
    public static string Get(this IReadOnlyDictionary<string, string[]> fields, string name, string fallback = "") =>
        fields.TryGetValue(name, out var v) ? (v.Length > 0 ? v[0] : "") : fallback;

    /// <summary>A checkbox: present and true / on (Test-AkariUaOn).</summary>
    public static bool On(this IReadOnlyDictionary<string, string[]> fields, string name) =>
        fields.Get(name) is "true" or "True" or "on";
}

/// <summary>
/// The choices as his bookmark URL, written as a file's first comment so a file from his site or from Akari opens
/// again (src\Core\Unattend.ps1: ConvertTo- / ConvertFrom-AkariUnattendQuery, ConvertFrom-AkariUnattend).
/// </summary>
public static partial class UnattendQuery
{
    public const string Site = "https://schneegans.de/windows/unattend-generator/";

    /// <summary>The fields a password lives in: never written to the comment ($AkariUaSecretFields).</summary>
    public static readonly IReadOnlySet<string> Secret = new HashSet<string>(
        ["BuiltinAdministratorPassword", "WifiPassword", .. Enumerable.Range(0, 15).Select(i => $"AccountPassword{i}")],
        StringComparer.OrdinalIgnoreCase);

    /// <summary>The fields as his URL, names in PowerShell's Sort-Object order, no passwords; '-' is %2D ('--' can't
    /// be in a comment).</summary>
    public static string To(IReadOnlyDictionary<string, string[]> fields)
    {
        var pairs = new List<string>();
        foreach (var k in fields.Keys.Order(StringComparer.CurrentCultureIgnoreCase))
        {
            if (Secret.Contains(k)) continue;
            foreach (var v in fields[k]) pairs.Add(Escape(k) + "=" + Escape(v).Replace("-", "%2D"));
        }
        return Site + "?" + string.Join("&", pairs);
    }

    /// <summary>The fields of his URL: a name given twice keeps both values; '+' is a space.</summary>
    public static Dictionary<string, string[]> From(string url)
    {
        var f = UnattendFields.New();
        foreach (var p in url[(url.IndexOf('?') + 1)..].Split('&'))
        {
            if (p.Length == 0) continue;
            var i = p.IndexOf('=');
            var k = Uri.UnescapeDataString(p[..Math.Max(i, 0)].Replace('+', ' '));
            var v = i >= 0 ? Uri.UnescapeDataString(p[(i + 1)..].Replace('+', ' ')) : "";
            if (k.Length == 0) continue;
            f[k] = f.TryGetValue(k, out var had) ? [.. had, v] : [v];
        }
        return f;
    }

    /// <summary>The fields of a file made by his site or by Akari (its first comment), or null.</summary>
    public static Dictionary<string, string[]>? FromXml(string xml)
    {
        var m = CommentPattern().Match(xml);
        return m.Success ? From(m.Groups[1].Value) : null;
    }

    [GeneratedRegex(@"<!--(https://schneegans\.de/windows/unattend-generator/\?[^>]*?)-->", RegexOptions.IgnoreCase)]
    private static partial Regex CommentPattern();

    /// <summary>[uri]::EscapeDataString as 5.1 has it (RFC 2396): !*'() are left as they are.</summary>
    internal static string Escape(string s)
    {
        var e = new StringBuilder(Uri.EscapeDataString(s));
        foreach (var (code, c) in new[] { ("%21", "!"), ("%2A", "*"), ("%27", "'"), ("%28", "("), ("%29", ")") }) e.Replace(code, c);
        return e.ToString();
    }
}
