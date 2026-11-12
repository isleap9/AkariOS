using System.Text.Json;
using AkariOS.Core.Update;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native updater's pure parts against src\Core\Update.ps1 on the same inputs (Oracle/Export-Update.ps1): the
/// release notes as text, the latest release read from GitHub's answer, and the update status.
/// </summary>
public sealed class UpdateOracleTests
{
    private static readonly string[] Notes =
    [
        "## What's new\n\n- **Faster** start\n* `code` and [a link](https://example.com)\n\n\n\n### Fixes\n+ __bold__ item\n  - nested",
        "Plain line   \r\nSecond line\r\n\r\n\r\n",
        "",
        "# Only a heading",
        "Text with **two** bold **parts** and `two` `codes`",
    ];

    private const string Assets = """
        [{ "name": "AkariOS-1.4.0.zip", "browser_download_url": "https://x/zip", "digest": "sha256:aa" },
         { "name": "AkariOS-Native.exe", "browser_download_url": "https://x/exe", "digest": "sha256:bb" }]
        """;

    /// <summary>GitHub's answers: status, body (JSON or null), the rate limit's reset (local time).</summary>
    private static readonly (int Status, string? Body, string? ResetAt)[] Releases =
    [
        (200, $$"""{ "tag_name": "v1.4.0", "body": "## New\n- a", "html_url": "https://x/v1.4.0", "assets": {{Assets}} }""", null),
        (200, """{ "tag_name": "1.2", "body": null, "html_url": "https://x/1.2", "assets": [] }""", null),
        (200, """{ "tag_name": "vv2.0.1", "html_url": "https://x/2" }""", null),
        (200, """{ "tag_name": "latest", "body": "x", "html_url": "https://x/latest", "assets": [] }""", null),
        (404, null, null),
        (429, null, "2026-11-12T14:05:00"),
        (429, null, null),
        (0, null, null),
        (500, null, null),
    ];

    /// <summary>The running version, the release (Ok and its version, or the failure), a change running, a Run in
    /// phases saved.</summary>
    private static readonly (string Current, bool Ok, string Version, string Message, bool Busy, bool Run)[] Statuses =
    [
        ("1.3.0", false, "", "No releases yet.", false, false),
        ("1.3.0", true, "1.4.0", "", false, false),
        ("1.4.0", true, "1.4.0", "", false, false),
        ("1.4", true, "1.4.0", "", false, false),
        ("1.5.0", true, "1.4.0", "", false, false),
        ("1.3.0", true, "1.4.0", "", true, false),
        ("1.3.0", true, "1.4.0", "", false, true),
        ("1.3.0", true, "1.4.0", "", true, true),
        ("1.4.0", true, "1.4.0", "", true, true),
    ];

    private static Release ReleaseOf(bool ok, string version, string message) =>
        ok ? new Release(true, Version.Parse(version), "", null, null, null, null) : Release.Failed(message);

    private static GitHubAnswer Answer((int Status, string? Body, string? ResetAt) c) =>
        new(c.Status, c.Body is null ? null : JsonDocument.Parse(c.Body).RootElement.Clone(), c.ResetAt is null ? null : DateTime.Parse(c.ResetAt));

    private sealed class FakeGitHub(GitHubAnswer answer) : IGitHub
    {
        public List<string> Paths { get; } = [];
        public GitHubAnswer Get(string path) { Paths.Add(path); return answer; }
    }

    private static readonly Lazy<JsonElement> PowerShell = new(() =>
    {
        var cases = Path.Combine(Path.GetTempPath(), $"akari-update-cases-{Guid.NewGuid():N}.json");
        var releases = Releases.Select(r => new { r.Status, Body = r.Body is null ? null : JsonDocument.Parse(r.Body).RootElement.Clone() as JsonElement?, r.ResetAt });
        var statuses = Statuses.Select(s => new { s.Current, s.Ok, s.Version, s.Message, s.Busy, s.Run });
        File.WriteAllText(cases, JsonSerializer.Serialize(new { Notes, Releases = releases, Status = statuses }));
        try { return Oracle.Run("Export-Update.ps1", "-Src", Repo.Src, "-Cases", cases); }
        finally { File.Delete(cases); }
    });

    [Fact]
    public void Notes_text_is_powershells()
    {
        var expected = PowerShell.Value.GetProperty("Notes").EnumerateArray().Select(e => e.GetString()!).ToList();
        Assert.Equal(expected, Notes.Select(Updates.NotesText).ToList());
    }

    [Fact]
    public void The_latest_release_reads_as_powershells()
    {
        var expected = PowerShell.Value.GetProperty("Releases").EnumerateArray()
            .Select(e => string.Join(" | ", e.GetProperty("Ok").GetBoolean(), e.GetProperty("Version").GetString(),
                e.GetProperty("Message").GetString(), e.GetProperty("Notes").GetString(), e.GetProperty("PageUrl").GetString())).ToList();
        var actual = Releases.Select(c => Updates.Latest(new FakeGitHub(Answer(c))))
            .Select(r => string.Join(" | ", r.Ok, r.Version?.ToString() ?? "", r.Message ?? "", r.Notes, r.PageUrl ?? "")).ToList();
        Assert.Equal(expected, actual);
    }

    [Fact]
    public void The_status_is_powershells()
    {
        var expected = PowerShell.Value.GetProperty("Status").EnumerateArray()
            .Select(e => $"{e.GetProperty("Kind").GetString()}: {e.GetProperty("Message").GetString()}").ToList();
        var actual = Statuses
            .Select(s => Updates.Status(s.Current, ReleaseOf(s.Ok, s.Version, s.Message), new UpdateBlocks(DeveloperCopy: false, RunSaved: s.Run, Busy: s.Busy)))
            .Select(u => $"{u.Kind}: {u.Message}").ToList();
        Assert.Equal(expected, actual);
    }

    [Fact]
    public void A_developer_build_is_blocked_before_anything_else()
    {
        var u = Updates.Status("1.3.0", ReleaseOf(true, "1.4.0", ""), new UpdateBlocks(DeveloperCopy: true, RunSaved: true, Busy: true));
        Assert.Equal(UpdateKind.Blocked, u.Kind);
        Assert.Equal("AkariOS 1.4.0 is available. This is a developer build: run a release's AkariOS-Native.exe to update.", u.Message);
        Assert.Equal(UpdateKind.Latest, Updates.Status("1.4.0", ReleaseOf(true, "1.4.0", ""), new UpdateBlocks(true, false, false)).Kind);
    }

    [Fact]
    public void The_latest_release_is_asked_of_the_repo_and_carries_the_exe()
    {
        var github = new FakeGitHub(Answer(Releases[0]));
        var r = Updates.Latest(github);
        Assert.Equal(["repos/isleap9/AkariOS/releases/latest"], github.Paths);
        Assert.Equal("https://x/exe", r.AssetUrl);
        Assert.Equal("sha256:bb", r.Digest);
        var none = Updates.Latest(new FakeGitHub(Answer(Releases[1])));
        Assert.True(none.Ok);
        Assert.Null(none.AssetUrl);
        Assert.Null(none.Digest);
    }
}
