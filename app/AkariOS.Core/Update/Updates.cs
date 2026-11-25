using System.Text.Json;
using System.Text.RegularExpressions;

namespace AkariOS.Core.Update;

/// <summary>GitHub's answer to an API call (Invoke-AkariGitHubApi): Status 0 = no connection, 429 = the rate limit
/// (with the local time it resets), Body = the parsed JSON on 200.</summary>
public sealed record GitHubAnswer(int Status, JsonElement? Body, DateTime? ResetAt);

/// <summary>GitHub's REST API (GET https://api.github.com/&lt;path&gt;). Never throws.</summary>
public interface IGitHub
{
    GitHubAnswer Get(string path);
}

/// <summary>The latest stable release (Get-AkariLatestRelease): its version and notes, and the native app's exe
/// (AssetUrl, Digest = GitHub's "sha256:…"; null when the release has none). Not Ok = Message says why.</summary>
public sealed record Release(bool Ok, Version? Version, string Notes, string? PageUrl, string? AssetUrl, string? Digest, string? Message)
{
    /// <summary>The installer (AkariOS-Native-Setup.exe) and its "sha256:…": what an installed copy updates from.</summary>
    public string? SetupUrl { get; init; }

    public string? SetupDigest { get; init; }

    public static Release Failed(string message) => new(false, null, "", null, null, null, message);
}

public enum UpdateKind { Available, Latest, Newer, Blocked, Error }

/// <summary>What About and the launch check show (Get-AkariUpdateStatus).</summary>
public sealed record UpdateStatus(UpdateKind Kind, string Message, Release Release);

/// <summary>What keeps a newer release from being installed now: a developer build (not a published single-file
/// exe), a saved Run in phases, changes being applied.</summary>
public sealed record UpdateBlocks(bool DeveloperCopy, bool RunSaved, bool Busy);

/// <summary>The updater's pure parts (src/Core/Update.ps1).</summary>
public static class Updates
{
    public const string Repo = "isleap9/AkariOS";

    /// <summary>The native app's release asset (the PowerShell updater picks AkariOS-*.zip).</summary>
    public const string Asset = "AkariOS-Native.exe";

    /// <summary>The native app's installer (build/AkariOS-Native.iss, Inno Setup), on the same release.</summary>
    public const string SetupAsset = "AkariOS-Native-Setup.exe";

    /// <summary>Inno Setup's uninstaller, next to an installed exe: that copy updates through the setup.</summary>
    public const string Uninstaller = "unins000.exe";

    /// <summary>The exe was put there by the setup (Program Files\AkariOS), not run as a portable copy.</summary>
    public static bool IsInstalled(string exePath) =>
        Path.GetDirectoryName(exePath) is { Length: > 0 } dir && File.Exists(Path.Combine(dir, Uninstaller));

    public const string ReleasesPage = $"https://github.com/{Repo}/releases";

    // PowerShell's -replace is case-insensitive
    private const RegexOptions Ps = RegexOptions.IgnoreCase | RegexOptions.CultureInvariant;

    /// <summary>The latest stable release, read from GitHub (Get-AkariLatestRelease).</summary>
    public static Release Latest(IGitHub github)
    {
        var r = github.Get($"repos/{Repo}/releases/latest");
        if (r.Status == 0) return Release.Failed("Couldn't reach GitHub. Check the internet connection.");
        if (r.Status == 429)
        {
            var when = r.ResetAt is { } at ? $" after {at:HH:mm}" : " later";
            return Release.Failed($"GitHub's limit was reached. Try again{when}.");
        }
        if (r.Status == 404) return Release.Failed("No releases yet.");
        if (r.Status != 200 || r.Body is not { } b) return Release.Failed($"GitHub answered with error {r.Status}. Try again later.");
        var tag = Str(b, "tag_name") ?? "";
        if (!Version.TryParse(tag.TrimStart('v'), out var v)) return Release.Failed($"The latest release ({tag}) has no version number.");
        var asset = AssetOf(b, Asset);
        var setup = AssetOf(b, SetupAsset);
        return new Release(true, v, Str(b, "body") ?? "", Str(b, "html_url"),
            asset is { } a1 ? Str(a1, "browser_download_url") : null, asset is { } a2 ? Str(a2, "digest") : null, null)
        {
            SetupUrl = setup is { } s1 ? Str(s1, "browser_download_url") : null,
            SetupDigest = setup is { } s2 ? Str(s2, "digest") : null,
        };
    }

    private static JsonElement? AssetOf(JsonElement release, string name) =>
        release.TryGetProperty("assets", out var assets) && assets.ValueKind == JsonValueKind.Array
            ? assets.EnumerateArray().Where(a => string.Equals(Str(a, "name"), name, StringComparison.OrdinalIgnoreCase)).Cast<JsonElement?>().FirstOrDefault()
            : null;

    /// <summary>The release against the running version (Get-AkariUpdateStatus; a developer build in place of its
    /// git checkout).</summary>
    public static UpdateStatus Status(string current, Release release, UpdateBlocks blocks)
    {
        if (!release.Ok || release.Version is not { } latest) return new(UpdateKind.Error, release.Message ?? "", release);
        var mine = Version.Parse(current);
        if (latest > mine)
        {
            var why = blocks.DeveloperCopy ? $"This is a developer build: run a release's {SetupAsset} to update."
                : blocks.RunSaved ? "Update once the Run in phases has finished."
                : blocks.Busy ? "Update once the changes being applied are done."
                : null;
            return why is null
                ? new(UpdateKind.Available, $"AkariOS {latest} is available (you have {mine}).", release)
                : new(UpdateKind.Blocked, $"AkariOS {latest} is available. {why}", release);
        }
        return latest == mine
            ? new(UpdateKind.Latest, $"You have the latest version ({mine}).", release)
            : new(UpdateKind.Newer, $"This copy ({mine}) is newer than the latest release ({latest}).", release);
    }

    private static string? Str(JsonElement o, string name) =>
        o.ValueKind == JsonValueKind.Object && o.TryGetProperty(name, out var p) && p.ValueKind == JsonValueKind.String ? p.GetString() : null;

    /// <summary>Release notes for About and the update dialog (ConvertTo-AkariNotesText): Markdown as plain text,
    /// headings, bold, code and link marks dropped, list items as bullets, at most one blank line in a row.</summary>
    public static string NotesText(string markdown)
    {
        var lines = markdown.Replace("\r", "").Split('\n').Select(l =>
        {
            l = Regex.Replace(l, @"^\s*#{1,6}\s*", "", Ps);
            l = Regex.Replace(l, @"^(\s*)[-*+]\s+", "$1• ", Ps);
            l = Regex.Replace(l, @"\[([^\]]*)\]\([^)]*\)", "$1", Ps);
            l = Regex.Replace(l, @"(\*\*|__)(.+?)\1", "$2", Ps);
            l = Regex.Replace(l, "`([^`]*)`", "$1", Ps);
            return l.TrimEnd();
        });
        return Regex.Replace(string.Join("\n", lines), "\n{3,}", "\n\n", Ps).Trim();
    }
}
