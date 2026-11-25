using System.Security.Cryptography;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;

namespace AkariOS.Core.Tests;

/// <summary>The native self-update (Updater) in a temp folder: the download checked against GitHub's SHA-256 and the
/// release's version, then the running exe renamed to .old, the new one put in its place and started.</summary>
public sealed class UpdaterTests : IDisposable
{
    private static readonly byte[] OldExe = [1, 2, 3];
    private static readonly byte[] NewExe = [7, 8, 9, 10];

    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-updater-{Guid.NewGuid():N}");
    private readonly string _exe;
    private readonly FakeHttp _http = new();
    private readonly FakeExe _run = new();
    private string? _version = "1.4.0";

    public UpdaterTests()
    {
        Directory.CreateDirectory(_dir);
        _exe = Path.Combine(_dir, "AkariOS-Native (1).exe");
        File.WriteAllBytes(_exe, OldExe);
    }

    public void Dispose() => Directory.Delete(_dir, recursive: true);

    [Theory]
    // dotnet build: the assemblies beside the exe
    [InlineData(@"C:\repo\app\AkariOS.App\bin\Debug\AkariOS.Core.dll", @"C:\repo\app\AkariOS.App\bin\Debug\AkariOS-Native.exe", true)]
    // a WinUI single-file publish unpacks its assemblies to %TEMP%\.net (the 1.5.0 setup's copy said "developer build")
    [InlineData(@"C:\Users\me\AppData\Local\Temp\.net\AkariOS-Native\abc123\AkariOS.Core.dll", @"C:\Program Files\AkariOS\AkariOS-Native.exe", false)]
    // a plain single-file publish: no Location
    [InlineData("", @"C:\Program Files\AkariOS\AkariOS-Native.exe", false)]
    [InlineData(null, null, false)]
    public void A_developer_build_is_one_whose_assemblies_sit_beside_the_exe(string? assembly, string? exe, bool developer) =>
        Assert.Equal(developer, AkariInfo.IsDeveloperBuild(assembly, exe));

    private sealed class FakeHttp : IHttp
    {
        public byte[] Body { get; set; } = NewExe;
        public Exception? Error { get; set; }
        public List<(string Url, string File)> Calls { get; } = [];

        public void Download(string url, string file)
        {
            Calls.Add((url, file));
            if (Error is not null) throw Error;
            File.WriteAllBytes(file, Body);
        }
    }

    private sealed class FakeExe : IExe
    {
        public Exception? Error { get; set; }
        public List<(string Path, string Args, bool Wait)> Calls { get; } = [];

        public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true)
        {
            Calls.Add((path, arguments, wait));
            if (Error is not null) throw Error;
            return new ExeResult(0, "");
        }
    }

    private Updater Make() => new(_http, _run, new MemoryLog(), _ => _version);

    private static string Digest(byte[] bytes) => "sha256:" + Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    private static Release Release(string? digest, string? url = "https://x/AkariOS-Native.exe") =>
        new(true, new Version(1, 4, 0), "", "https://x/v1.4.0", url, digest, null);

    private string[] Files() => Directory.GetFiles(_dir).Select(Path.GetFileName).Order(StringComparer.Ordinal).ToArray()!;

    private void Untouched()
    {
        Assert.Equal(OldExe, File.ReadAllBytes(_exe));
        Assert.Equal(["AkariOS-Native (1).exe"], Files());
        Assert.Empty(_run.Calls);
    }

    [Fact]
    public void Installs_the_new_exe_in_place_and_starts_it()
    {
        var r = Make().Install(Release(Digest(NewExe)), _exe);

        Assert.Equal(new UpdateResult(true, "Installing AkariOS 1.4.0. AkariOS will restart."), r);
        Assert.Equal([("https://x/AkariOS-Native.exe", _exe + ".new")], _http.Calls);
        Assert.Equal(NewExe, File.ReadAllBytes(_exe));
        Assert.Equal(OldExe, File.ReadAllBytes(_exe + ".old"));
        Assert.Equal([(_exe, "", false)], _run.Calls);
    }

    [Fact]
    public void An_old_copy_left_from_before_is_replaced()
    {
        File.WriteAllBytes(_exe + ".old", [42]);
        Assert.True(Make().Install(Release(Digest(NewExe)), _exe).Ok);
        Assert.Equal(OldExe, File.ReadAllBytes(_exe + ".old"));
    }

    [Fact]
    public void A_release_with_neither_the_exe_nor_the_setup_is_refused()
    {
        var r = Make().Install(Release(Digest(NewExe), url: null), _exe);
        Assert.Equal(new UpdateResult(false, "The release has no AkariOS-Native-Setup.exe."), r);
        Assert.Empty(_http.Calls);
        Untouched();
    }

    [Fact]
    public void A_portable_copy_runs_the_setup_of_a_release_without_the_exe()
    {
        var temp = Path.Combine(_dir, "temp");
        Directory.CreateDirectory(temp);
        var release = Release(null, url: null) with { SetupUrl = "https://x/AkariOS-Native-Setup.exe", SetupDigest = Digest(NewExe) };
        var r = new Updater(_http, _run, new MemoryLog(), _ => _version, temp).Install(release, _exe);

        var setup = Path.Combine(temp, "AkariOS-Native-Setup-1.4.0.exe");
        Assert.Equal(new UpdateResult(true, "Installing AkariOS 1.4.0. AkariOS will restart."), r);
        Assert.Equal([("https://x/AkariOS-Native-Setup.exe", setup)], _http.Calls);
        Assert.Equal([(setup, Updater.SetupArgs, false)], _run.Calls);
        Assert.Equal(OldExe, File.ReadAllBytes(_exe));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("sha256:abc")]
    [InlineData("md5:0123456789abcdef0123456789abcdef")]
    public void No_checksum_means_no_download(string? digest)
    {
        var r = Make().Install(Release(digest), _exe);
        Assert.Equal(new UpdateResult(false, "GitHub gave no checksum for the download, so it can't be checked. Not installing it."), r);
        Assert.Empty(_http.Calls);
        Untouched();
    }

    [Fact]
    public void A_failed_download_changes_nothing()
    {
        _http.Error = new HttpRequestException("timed out");
        var r = Make().Install(Release(Digest(NewExe)), _exe);
        Assert.Equal(new UpdateResult(false, "The download failed: timed out"), r);
        Untouched();
    }

    [Fact]
    public void A_download_that_doesnt_match_the_checksum_is_deleted()
    {
        _http.Body = [6, 6, 6];
        var r = Make().Install(Release(Digest(NewExe)), _exe);
        Assert.Equal(new UpdateResult(false, "The download doesn't match GitHub's checksum. Not installing it."), r);
        Untouched();
    }

    [Fact]
    public void An_upper_case_checksum_matches() =>
        Assert.True(Make().Install(Release(Digest(NewExe).ToUpperInvariant()), _exe).Ok);

    [Theory]
    [InlineData("1.3.0", "The download is AkariOS-Native.exe 1.3.0, not 1.4.0. Not installing it.")]
    [InlineData(null, "The download isn't an AkariOS-Native.exe with a version. Not installing it.")]
    public void A_download_of_another_version_is_deleted(string? version, string message)
    {
        _version = version;
        var r = Make().Install(Release(Digest(NewExe)), _exe);
        Assert.Equal(new UpdateResult(false, message), r);
        Untouched();
    }

    [Fact]
    public void When_the_new_exe_wont_start_the_old_one_is_put_back()
    {
        _run.Error = new InvalidOperationException("blocked");
        var r = Make().Install(Release(Digest(NewExe)), _exe);
        Assert.Equal(new UpdateResult(false, "The new version didn't start (blocked). The old version was put back."), r);
        Assert.Equal(OldExe, File.ReadAllBytes(_exe));
        Assert.Equal(["AkariOS-Native (1).exe"], Files());
    }

    [Fact]
    public void Cleanup_removes_the_old_and_new_copies()
    {
        File.WriteAllBytes(_exe + ".old", OldExe);
        File.WriteAllBytes(_exe + ".new", NewExe);
        Updater.Cleanup(_exe, _ => { });
        Assert.Equal(["AkariOS-Native (1).exe"], Files());
    }

    [Fact]
    public void Cleanup_waits_for_the_old_exe_to_close()
    {
        File.WriteAllBytes(_exe + ".old", OldExe);
        var held = new FileStream(_exe + ".old", FileMode.Open, FileAccess.Read, FileShare.None);
        var sleeps = 0;
        Updater.Cleanup(_exe, _ => { if (++sleeps == 2) held.Dispose(); });
        Assert.Equal(2, sleeps);
        Assert.False(File.Exists(_exe + ".old"));
    }

    [Fact]
    public void The_real_github_and_downloads_cant_be_made_in_a_test()
    {
        Assert.Throws<InvalidOperationException>(() => new GitHubApi());
        Assert.Throws<InvalidOperationException>(() => new HttpDownloads());
    }

    [Theory]
    [InlineData(403, "0", 429)]
    [InlineData(403, "12", 403)]
    [InlineData(403, null, 403)]
    [InlineData(500, null, 500)]
    public void A_refusal_with_no_requests_left_is_the_rate_limit(int status, string? remaining, int expected) =>
        Assert.Equal(expected, GitHubApi.StatusOf(status, remaining));

    [Fact]
    public void The_reset_header_is_local_time()
    {
        Assert.Equal(DateTimeOffset.FromUnixTimeSeconds(1_800_000_000).LocalDateTime, GitHubApi.ResetOf("1800000000"));
        Assert.Null(GitHubApi.ResetOf(null));
        Assert.Null(GitHubApi.ResetOf("soon"));
    }

    // ---- a copy the setup installed: the release's setup, checked, then run silently

    private string Installed()
    {
        File.WriteAllBytes(Path.Combine(_dir, Updates.Uninstaller), [0]);
        var temp = Path.Combine(_dir, "temp");
        Directory.CreateDirectory(temp);
        return temp;
    }

    private static Release WithSetup(string? digest, string? url = "https://x/AkariOS-Native-Setup.exe") =>
        Release(null, null) with { SetupUrl = url, SetupDigest = digest };

    [Fact]
    public void An_installed_copy_runs_the_release_setup_silently()
    {
        var temp = Installed();
        _version = "1.4.0                                             ";
        var r = new Updater(_http, _run, new MemoryLog(), _ => _version, temp).Install(WithSetup(Digest(NewExe)), _exe);

        var setup = Path.Combine(temp, "AkariOS-Native-Setup-1.4.0.exe");
        Assert.Equal(new UpdateResult(true, "Installing AkariOS 1.4.0. AkariOS will restart."), r);
        Assert.Equal([("https://x/AkariOS-Native-Setup.exe", setup)], _http.Calls);
        Assert.Equal([(setup, "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RELAUNCH=1", false)], _run.Calls);
        // the exe itself is the setup's to replace
        Assert.Equal(OldExe, File.ReadAllBytes(_exe));
        Assert.False(File.Exists(_exe + ".old"));
    }

    [Fact]
    public void An_installed_copy_refuses_a_release_without_the_setup()
    {
        var temp = Installed();
        var r = new Updater(_http, _run, new MemoryLog(), _ => _version, temp).Install(WithSetup(Digest(NewExe), url: null), _exe);
        Assert.Equal(new UpdateResult(false, "The release has no AkariOS-Native-Setup.exe."), r);
        Assert.Empty(_http.Calls);
        Assert.Empty(_run.Calls);
    }

    [Theory]
    [InlineData(new byte[] { 6, 6, 6 }, "1.4.0", "The download doesn't match GitHub's checksum. Not installing it.")]
    [InlineData(new byte[] { 7, 8, 9, 10 }, "1.3.0", "The download is AkariOS-Native-Setup.exe 1.3.0, not 1.4.0. Not installing it.")]
    public void An_installed_copy_deletes_a_setup_that_fails_its_checks(byte[] body, string version, string message)
    {
        var temp = Installed();
        _http.Body = body;
        _version = version;
        var r = new Updater(_http, _run, new MemoryLog(), _ => _version, temp).Install(WithSetup(Digest(NewExe)), _exe);
        Assert.Equal(new UpdateResult(false, message), r);
        Assert.Empty(Directory.GetFiles(temp));
        Assert.Empty(_run.Calls);
    }

    [Fact]
    public void An_installed_copy_whose_setup_wont_start_changes_nothing()
    {
        var temp = Installed();
        _run.Error = new InvalidOperationException("blocked");
        var r = new Updater(_http, _run, new MemoryLog(), _ => _version, temp).Install(WithSetup(Digest(NewExe)), _exe);
        Assert.Equal(new UpdateResult(false, "The setup didn't start (blocked). Nothing was changed."), r);
        Assert.Empty(Directory.GetFiles(temp));
        Assert.Equal(OldExe, File.ReadAllBytes(_exe));
    }

    [Fact]
    public void Cleanup_gives_up_quietly()
    {
        File.WriteAllBytes(_exe + ".old", OldExe);
        using var held = new FileStream(_exe + ".old", FileMode.Open, FileAccess.Read, FileShare.None);
        Updater.Cleanup(_exe, _ => { });
        Assert.True(File.Exists(_exe + ".old"));
    }
}
