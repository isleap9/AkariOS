using System.Diagnostics;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using AkariOS.Core.Machine;

namespace AkariOS.Core.Update;

/// <summary>A download over HTTPS (Save-AkariUpdateFile, Invoke-WebRequest); throws when it fails. Headers given replace
/// the client's own (a vendor site that serves browsers only).</summary>
public interface IHttp
{
    void Download(string url, string file);

    void Download(string url, string file, IReadOnlyDictionary<string, string>? headers)
    {
        if (headers is { Count: > 0 }) throw new NotSupportedException("this downloader takes no headers");
        Download(url, file);
    }

    /// <summary>A page's text (Invoke-WebRequest's Content).</summary>
    string Text(string url, IReadOnlyDictionary<string, string>? headers = null) => throw new NotSupportedException("this downloader reads no pages");

    /// <summary>A form posted (application/x-www-form-urlencoded) and the answer saved to a file (Invoke-WebRequest
    /// -Method Post -Body -OutFile: UUP Dump's converter package); throws when it fails.</summary>
    void Post(string url, IReadOnlyDictionary<string, string> form, string file) => throw new NotSupportedException("this downloader posts no forms");
}

public sealed record UpdateResult(bool Ok, string Message);

/// <summary>
/// The native self-update (Install-AkariUpdate for one exe): the release's AkariOS-Native.exe is downloaded next to
/// the running one as &lt;exe&gt;.new and checked against GitHub's SHA-256 and the release's version; then the running
/// exe is renamed to &lt;exe&gt;.old (Windows lets a running exe be renamed, not overwritten), the new one takes its
/// name and is started. On Ok the caller closes the app; the new one removes the .old copy on launch
/// (<see cref="Cleanup"/>). No helper process.
/// </summary>
public sealed class Updater(IHttp http, IExe exe, IAkariLog log, Func<string, string?>? versionOf = null)
{
    private readonly Func<string, string?> _versionOf = versionOf ?? (f => FileVersionInfo.GetVersionInfo(f).ProductVersion);

    public UpdateResult Install(Release release, string exePath)
    {
        var r = Try(release, exePath);
        log.WriteFile($"Update: {r.Message}");
        return r;
    }

    private UpdateResult Try(Release release, string exePath)
    {
        if (string.IsNullOrEmpty(release.AssetUrl)) return new(false, $"The release has no {Updates.Asset}.");
        var digest = Regex.Match(release.Digest ?? "", "^sha256:([0-9a-fA-F]{64})$", RegexOptions.IgnoreCase);
        if (!digest.Success) return new(false, "GitHub gave no checksum for the download, so it can't be checked. Not installing it.");

        var fresh = exePath + ".new";
        var old = exePath + ".old";
        Delete(fresh);
        try { http.Download(release.AssetUrl, fresh); }
        catch (Exception e) { Delete(fresh); return new(false, $"The download failed: {e.Message}"); }

        string hash;
        using (var f = File.OpenRead(fresh)) hash = Convert.ToHexString(SHA256.HashData(f));
        if (!hash.Equals(digest.Groups[1].Value, StringComparison.OrdinalIgnoreCase))
        {
            Delete(fresh);
            return new(false, "The download doesn't match GitHub's checksum. Not installing it.");
        }
        var got = _versionOf(fresh);
        if (!Version.TryParse(got, out var v))
        {
            Delete(fresh);
            return new(false, $"The download isn't an {Updates.Asset} with a version. Not installing it.");
        }
        if (v != release.Version)
        {
            Delete(fresh);
            return new(false, $"The download is {Updates.Asset} {v}, not {release.Version}. Not installing it.");
        }

        try
        {
            Delete(old);
            File.Move(exePath, old);
        }
        catch (Exception e) { Delete(fresh); return new(false, $"The update failed ({e.Message}). Nothing was changed."); }
        try
        {
            File.Move(fresh, exePath);
            exe.Run(exePath, "", wait: false);
            return new(true, $"Installing AkariOS {release.Version}. AkariOS will restart.");
        }
        catch (Exception e)
        {
            Delete(exePath);
            File.Move(old, exePath);
            Delete(fresh);
            return new(false, $"The new version didn't start ({e.Message}). The old version was put back.");
        }
    }

    private static void Delete(string file)
    {
        if (File.Exists(file)) File.Delete(file);
    }

    /// <summary>On launch (Remove-AkariUpdateLeftover): the .old copy and a stray .new go. The old exe may still be
    /// closing: tried a few times, then left for the next launch.</summary>
    public static void Cleanup(string exePath, Action<TimeSpan>? sleep = null, int tries = 10)
    {
        sleep ??= Thread.Sleep;
        foreach (var file in new[] { exePath + ".old", exePath + ".new" })
        {
            for (var i = 0; i < tries && File.Exists(file); i++)
            {
                try { File.Delete(file); }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException) { sleep(TimeSpan.FromMilliseconds(500)); }
            }
        }
    }
}
