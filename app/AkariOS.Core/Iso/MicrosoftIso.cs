using System.Net;
using System.Text.RegularExpressions;

namespace AkariOS.Core.Iso;

/// <summary>A row of Microsoft's published hash table: the ISO's language ("English International 64-bit") and its
/// SHA-256 (upper-case hex).</summary>
public sealed record MicrosoftHash(string Language, string Sha256);

/// <summary>
/// Windows 11 from Microsoft's own download page (plan docs/plans/2026-11-20-iso-builder-wizard.md, I5): the browser
/// downloads it (Microsoft's download service refuses automated requests, so AkariOS doesn't call it), AkariOS finds
/// the new ISO in Downloads and checks it against the SHA-256 table the same page publishes. Pure parts here; the
/// page is read and the file found through <see cref="IsoDownload"/>.
/// </summary>
public static partial class MicrosoftIso
{
    /// <summary>Microsoft's Windows 11 download page: the browser opens it, AkariOS reads its hash table.</summary>
    public const string Page = "https://www.microsoft.com/en-us/software-download/windows11";

    /// <summary>The names Microsoft gives its Windows 11 ISOs (Win11_25H2_English_x64.iso).</summary>
    public const string FilePattern = "Win11*.iso";

    /// <summary>The page's hash rows: a cell with the language, then one with 64 hex digits; none = an empty list
    /// (the page's layout changed).</summary>
    public static IReadOnlyList<MicrosoftHash> Hashes(string html) =>
        [.. HashRow().Matches(html).Select(m => new MicrosoftHash(
            WebUtility.HtmlDecode(m.Groups["lang"].Value).Trim(), m.Groups["hash"].Value.ToUpperInvariant()))
            .DistinctBy(h => h.Sha256)];

    /// <summary>The row whose hash is <paramref name="sha256"/>, else null.</summary>
    public static MicrosoftHash? Match(IReadOnlyList<MicrosoftHash> hashes, string sha256) =>
        hashes.FirstOrDefault(h => h.Sha256.Equals(sha256, StringComparison.OrdinalIgnoreCase));

    [GeneratedRegex(@"<td[^>]*>\s*(?<lang>[^<]+?)\s*</td>\s*<td[^>]*>\s*(?<hash>[0-9A-Fa-f]{64})\s*</td>", RegexOptions.IgnoreCase)]
    private static partial Regex HashRow();
}
