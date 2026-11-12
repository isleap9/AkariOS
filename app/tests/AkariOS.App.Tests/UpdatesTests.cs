using System.IO;
using System.Security.Cryptography;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Pages;
using AkariOS.App.Shell;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;
using static AkariOS.App.Tests.AppHarness;

namespace AkariOS.App.Tests;

/// <summary>The update check and install in the window (src/UI/About.ps1's part): About's version card, Home's update
/// bar, the launch prompt. GitHub, the download and the new exe's start are faked; the exe is a temp file.</summary>
[Collection("Motion")]
public sealed class UpdatesTests : IDisposable
{
    private static readonly byte[] NewExe = [7, 8, 9];

    private readonly AppHarness _h = new();
    private readonly FakeGitHub _github = new();
    private readonly FakeExe _run = new();
    private int _closed;

    public void Dispose() => _h.Dispose();

    private sealed class FakeGitHub : IGitHub
    {
        public int Status { get; set; } = 200;
        public string Tag { get; set; } = "v1.4.0";
        public string Digest { get; set; } = "sha256:" + Convert.ToHexString(SHA256.HashData(NewExe));
        public int Calls { get; private set; }

        public GitHubAnswer Get(string path)
        {
            Calls++;
            if (Status != 200) return new(Status, null, null);
            var body = JsonSerializer.Serialize(new
            {
                tag_name = Tag, body = "## New\n- **Faster** start", html_url = "https://x/release",
                assets = new[] { new { name = "AkariOS-Native.exe", browser_download_url = "https://x/exe", digest = Digest } },
            });
            return new(200, JsonDocument.Parse(body).RootElement.Clone(), null);
        }
    }

    private sealed class FakeHttp : IHttp
    {
        public void Download(string url, string file) => File.WriteAllBytes(file, NewExe);
    }

    private sealed class FakeExe : IExe
    {
        public List<string> Started { get; } = [];
        public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true) { Started.Add(path); return new(0, ""); }
    }

    private (AppTest T, UpdateService U, string Exe) Make(bool developer = false, bool runSaved = false)
    {
        var about = File.ReadAllText(Path.Combine(LookTests.RepoRoot(), "src", "UI", "About.psd1"));
        var t = _h.Make(Fixtures().Add("src/UI/About.psd1", about));
        Directory.CreateDirectory(_h.Dir);
        var exe = Path.Combine(_h.Dir, "AkariOS-Native.exe");
        File.WriteAllBytes(exe, [1]);
        var u = new UpdateService(_github, new Updater(new FakeHttp(), _run, t.S.Log, _ => "1.4.0"), exe, developer, () => runSaved, "1.3.0");
        t.S.Updates = u;
        t.S.Close = () => _closed++;
        return (t, u, exe);
    }

    private static Button Button(DependencyObject root, string text) =>
        All<Button>(root).First(b => b.Content as string == text);

    private static FrameworkElement Bar(DependencyObject home) =>
        All<Border>(home).First(b => b.Name == "UpdateBar");

    [Fact]
    public void The_launch_check_on_home_asks_and_updates() => LookTests.OnSta(() =>
    {
        var (t, u, exe) = Make();
        var home = HomePage.Build(t.S);
        t.Answers.Enqueue("Update now");
        u.Check(t.S, manual: false);

        Assert.Equal(UpdateKind.Available, u.Status!.Kind);
        Assert.Equal(Visibility.Visible, Bar(home).Visibility);
        Assert.Contains("AkariOS 1.4.0 is available (you have 1.3.0).", Texts(home));
        Assert.Equal(["AkariOS 1.4.0 is available (you have 1.3.0).\n\nWhat's new:\nNew\n• Faster start\n\nUpdate now? AkariOS closes, installs it and opens again. Your presets and settings are kept."], t.Asked);
        Assert.Equal(NewExe, File.ReadAllBytes(exe));
        Assert.Equal([exe], _run.Started);
        Assert.Equal(1, _closed);
    });

    [Fact]
    public void Later_leaves_the_bar() => LookTests.OnSta(() =>
    {
        var (t, u, _) = Make();
        var home = HomePage.Build(t.S);
        t.Answers.Enqueue("Later");
        u.Check(t.S, manual: false);
        Assert.Single(t.Asked);
        Assert.Empty(_run.Started);
        Assert.Equal(0, _closed);
        // the bar's Update now asks nothing more: it installs
        Click(Button(Bar(home), "Update now"));
        Assert.Equal([_h.Dir + @"\AkariOS-Native.exe"], _run.Started);
        Assert.Equal(1, _closed);
    });

    [Fact]
    public void Away_from_home_the_launch_check_doesnt_ask() => LookTests.OnSta(() =>
    {
        var (t, u, _) = Make();
        t.S.Shell.Open("About");
        u.Check(t.S, manual: false);
        Assert.Empty(t.Asked);
        Assert.Equal(UpdateKind.Available, u.Status!.Kind);
    });

    [Fact]
    public void Nothing_new_hides_the_bar() => LookTests.OnSta(() =>
    {
        var (t, u, _) = Make();
        _github.Tag = "v1.3.0";
        var home = HomePage.Build(t.S);
        u.Check(t.S, manual: false);
        Assert.Equal(Visibility.Collapsed, Bar(home).Visibility);
        Assert.Empty(t.Asked);
    });

    [Fact]
    public void About_checks_and_shows_the_status_and_notes() => LookTests.OnSta(() =>
    {
        var (t, u, _) = Make();
        var about = AboutPage.Build(t.S);
        Assert.Contains("Not checked yet.", Texts(about));
        Assert.Equal(Visibility.Collapsed, Button(about, "Update now").Visibility);

        _github.Status = 0;
        Click(Button(about, "Check for updates"));
        Assert.Contains("Couldn't reach GitHub. Check the internet connection.", Texts(about));
        var head = All<TextBlock>(about).First(b => b.Text == "What's new");
        Assert.Equal(Visibility.Collapsed, head.Visibility);

        _github.Status = 200;
        Click(Button(about, "Check for updates"));
        Assert.Equal(2, _github.Calls);
        Assert.Contains("AkariOS 1.4.0 is available (you have 1.3.0).", Texts(about));
        Assert.Contains("New\n• Faster start", Texts(about));
        Assert.Equal(Visibility.Visible, head.Visibility);
        Assert.Equal(Visibility.Visible, Button(about, "Update now").Visibility);
        // a manual check never asks
        Assert.Empty(t.Asked);
    });

    [Fact]
    public void Blocked_while_safe_mode_changes_wait() => LookTests.OnSta(() =>
    {
        var (t, u, _) = Make();
        u.Check(t.S, manual: true);
        t.Page.SafePending["fix-safe"] = new(Core.Tweaks.TweakMode.Apply, null);
        u.Install(t.S);
        Assert.Equal(["AkariOS 1.4.0 is available. Update once the changes being applied are done."], t.Asked);
        Assert.Empty(_run.Started);
    });

    [Theory]
    [InlineData(true, false, "This is a developer build: run a release's AkariOS-Native.exe to update.")]
    [InlineData(false, true, "Update once the Run in phases has finished.")]
    public void Blocked_for_a_developer_build_or_a_saved_run(bool developer, bool run, string why) => LookTests.OnSta(() =>
    {
        var (t, u, _) = Make(developer, run);
        var home = HomePage.Build(t.S);
        u.Check(t.S, manual: false);
        Assert.Equal(UpdateKind.Blocked, u.Status!.Kind);
        Assert.Contains($"AkariOS 1.4.0 is available. {why}", Texts(home));
        Assert.Equal(Visibility.Collapsed, Button(Bar(home), "Update now").Visibility);
        Assert.Empty(t.Asked);
    });

    [Fact]
    public void A_failed_install_says_why_and_stays_open() => LookTests.OnSta(() =>
    {
        var (t, u, exe) = Make();
        _github.Digest = "sha256:" + new string('0', 64);
        u.Check(t.S, manual: true);
        u.Install(t.S);
        Assert.Equal(["The download doesn't match GitHub's checksum. Not installing it."], t.Asked);
        Assert.False(t.S.Shell.Busy);
        Assert.Equal(0, _closed);
        Assert.Equal([1], File.ReadAllBytes(exe));
    });

    [Fact]
    public void The_real_one_reads_this_build() =>
        Assert.True(UpdateService.IsDeveloperBuild(), "tests run from dotnet's build output, not a single-file publish");
}
