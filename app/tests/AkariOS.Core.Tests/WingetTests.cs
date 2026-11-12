using System.IO.Compression;
using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;

namespace AkariOS.Core.Tests;

/// <summary>winget installs, App Installer and the Microsoft Store (src/Core/Winget.ps1) over a fake winget.exe,
/// package manager, downloads and programs: nothing real is installed.</summary>
public sealed class WingetTests : IDisposable
{
    private readonly FakeWingetExe _winget = new();
    private readonly FakePackages _pm = new();
    private readonly FakeDownloads _http = new();
    private readonly RecordingExe _exe = new();
    private readonly MemoryLog _log = new();
    private readonly List<TimeSpan> _sleeps = [];
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-winget-{Guid.NewGuid():N}");

    public void Dispose()
    {
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    private Winget Make() => new(_winget, _pm, _http, new AppPackages(_pm, new FakeDism(), _log), _exe, _log, _dir, @"C:\Windows", _sleeps.Add);

    private static readonly string[] Flags = ["--silent", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity"];

    private static string Install(string id, string source = "winget") =>
        string.Join(" ", new[] { "install", "--id", id, "--exact", "--source", source }.Concat(Flags));

    [Fact]
    public void Installs_with_the_flags_and_once_checks_the_tool()
    {
        var w = Make();
        w.Install("Valve.Steam");
        w.Install("Discord.Discord");
        Assert.Equal(["--version", Install("Valve.Steam"), Install("Discord.Discord")], _winget.Calls);
        Assert.Contains("winget: installing Valve.Steam", _log.Lines);
    }

    [Theory]
    [InlineData(-1978335135)]
    [InlineData(-1978335189)]
    public void Already_installed_codes_are_fine(int code)
    {
        _winget.Answer = a => a[0] == "install" ? new(code, []) : null;
        Make().Install("Valve.Steam");
    }

    [Fact]
    public void A_failure_says_wingets_last_line_with_letters()
    {
        _winget.Answer = a => a[0] == "install" ? new(-1978335212, ["Found Steam [Valve.Steam] Version 2.10", "No package found matching input criteria.", "  -  ", "   "]) : null;
        var e = Assert.Throws<InvalidOperationException>(() => Make().Install("Valve.Steam"));
        Assert.Equal("winget could not install Valve.Steam (0x8A150014): No package found matching input criteria.", e.Message);
    }

    [Fact]
    public void Installed_asks_winget_list()
    {
        _winget.Answer = a => a[0] == "list" ? new(0, ["Name   Id            Version", "Steam  valve.steam   2.10"]) : null;
        Assert.True(Make().Installed("Valve.Steam"));
        Assert.Equal(["list --id Valve.Steam --exact --source winget --accept-source-agreements --disable-interactivity"], _winget.Calls);

        _winget.Answer = a => a[0] == "list" ? new(-1978335212, ["No installed package found matching input criteria."]) : null;
        Assert.False(Make().Installed("Valve.Steam"));
        _winget.Missing = true;
        Assert.False(Make().Installed("Valve.Steam"));
    }

    [Theory]
    [InlineData("v1.9.25200", "1.9.25200")]
    [InlineData("v1.6.2771-preview", "1.6.2771")]
    [InlineData("  1.12.350  ", "1.12.350")]
    [InlineData("nonsense", null)]
    public void The_version_is_read_from_the_first_line(string line, string? version)
    {
        _winget.Answer = a => a[0] == "--version" ? new(0, [line, "x"]) : null;
        Assert.Equal(version is null ? null : Version.Parse(version), Make().ToolVersion());
    }

    [Fact]
    public void An_old_winget_gets_app_installer_registered_again()
    {
        var versions = new Queue<string>(["v1.5.0", "v1.9.0"]);
        _winget.Answer = a => a[0] == "--version" ? new(0, [versions.Dequeue()]) : null;
        Make().EnsureTool();
        Assert.Equal(["register-family Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"], _pm.Changes);
        Assert.Contains("winget: version 1.5.0 is too old, installing App Installer", _log.Lines);
        Assert.Empty(_http.Calls);
    }

    [Fact]
    public void No_winget_gets_app_installer_from_github()
    {
        _winget.Missing = true;
        _pm.OnChange = what => { if (what.StartsWith("add ") && what.EndsWith(".msixbundle")) _winget.Missing = false; };
        _http.Files["DesktopAppInstaller_Dependencies.zip"] = Zip(@"x64\Microsoft.VCLibs.x64.appx", @"x64\Microsoft.UI.Xaml.x64.appx", @"arm64\Microsoft.VCLibs.arm64.appx");
        Make().EnsureTool();
        Assert.Equal(["https://github.com/microsoft/winget-cli/releases/latest/download/DesktopAppInstaller_Dependencies.zip",
            "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"], _http.Calls);
        Assert.Equal(["register-family Microsoft.DesktopAppInstaller_8wekyb3d8bbwe", "add Microsoft.UI.Xaml.x64.appx", "add Microsoft.VCLibs.x64.appx", "add AppInstaller.msixbundle"],
            _pm.Changes.Select(c => c.StartsWith("add ") ? "add " + Path.GetFileName(c[4..]) : c));
        Assert.Contains("winget: not found, installing App Installer", _log.Lines);
        Assert.Contains("winget: version 1.9.0 installed", _log.Lines);
    }

    [Fact]
    public void Winget_that_wont_install_fails()
    {
        _winget.Missing = true;
        _http.Files["DesktopAppInstaller_Dependencies.zip"] = Zip();
        var e = Assert.Throws<InvalidOperationException>(() => Make().Install("Valve.Steam"));
        Assert.Equal("winget could not be installed", e.Message);
    }

    private static byte[] Zip(params string[] entries)
    {
        using var ms = new MemoryStream();
        using (var z = new ZipArchive(ms, ZipArchiveMode.Create))
            foreach (var e in entries) z.CreateEntry(e).Open().Dispose();
        return ms.ToArray();
    }

    private static AppPackage Store(string? location = null) =>
        new("Microsoft.WindowsStore", "Microsoft.WindowsStore_1_x64__8wekyb3d8bbwe", "Microsoft.WindowsStore_8wekyb3d8bbwe", location, false, false, false, false);

    [Fact]
    public void A_store_install_puts_the_store_back_first_from_the_disk()
    {
        var folder = Path.Combine(_dir, "Store");
        Directory.CreateDirectory(folder);
        File.WriteAllText(Path.Combine(folder, "AppxManifest.xml"), "<Package/>");
        // left on the disk for another user: registering it again brings it back
        _pm.Packages.Add(Store(folder) with { Name = "Microsoft.WindowsStore.Old" });
        _pm.OnChange = what => { if (what.StartsWith("register ")) _pm.Packages.Add(Store()); };
        Make().Install("9NBLGGH4NNS1", "msstore");
        Assert.Equal([$"register {Path.Combine(folder, "AppxManifest.xml")}"], _pm.Changes);
        Assert.Equal(["--version", Install("9NBLGGH4NNS1", "msstore")], _winget.Calls);
        Assert.Contains("Microsoft Store: registering it again", _log.Lines);
    }

    [Fact]
    public void The_store_comes_from_winget_when_its_files_are_gone()
    {
        _winget.Answer = a => { if (a.Contains("9WZDNCRFJBMP")) _pm.Packages.Add(Store()); return null; };
        Make().EnsureStore();
        Assert.Equal(["--version", Install("9WZDNCRFJBMP", "msstore")], _winget.Calls);
        Assert.Empty(_exe.Calls);
    }

    [Fact]
    public void Then_windows_reinstalls_it_and_akari_waits()
    {
        _winget.Answer = a => a.Contains("9WZDNCRFJBMP") ? new(-1, ["Error: the source is down"]) : null;
        var waits = 0;
        _exe.OnRun = () => { };
        var w = new Winget(_winget, _pm, _http, new AppPackages(_pm, new FakeDism(), _log), _exe, _log, _dir, @"C:\Windows",
            t => { _sleeps.Add(t); if (++waits == 3) _pm.Packages.Add(Store()); });
        w.EnsureStore();
        Assert.Equal([(@"C:\Windows\System32\wsreset.exe", "-i", false)], _exe.Calls);
        Assert.Equal([TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5)], _sleeps);
        Assert.Contains("Microsoft Store: winget failed (0xFFFFFFFF): Error: the source is down", _log.Lines);
    }

    [Fact]
    public void A_store_still_missing_after_five_minutes_fails()
    {
        _winget.Missing = true;
        _http.Files["DesktopAppInstaller_Dependencies.zip"] = Zip();
        var e = Assert.Throws<InvalidOperationException>(() => Make().EnsureStore());
        Assert.Equal("the Microsoft Store is still downloading: try again in a few minutes", e.Message);
        Assert.Equal(60, _sleeps.Count);
        Assert.Contains("Microsoft Store: winget failed: winget could not be installed", _log.Lines);
    }

    [Fact]
    public void The_real_one_cant_be_made_in_a_test() => Assert.Throws<InvalidOperationException>(() => new WingetExe());
}

/// <summary>winget.exe: "--version" answers v1.9.0, the rest code 0; Answer overrides (null = the default);
/// Missing = not on the PC (Run throws).</summary>
internal sealed class FakeWingetExe : IWinget
{
    public List<string> Calls { get; } = [];
    public bool Missing { get; set; }
    public Func<string[], WingetResult?>? Answer { get; set; }

    public WingetResult Run(params string[] arguments)
    {
        if (Missing) throw new InvalidOperationException("winget is not available");
        Calls.Add(string.Join(" ", arguments));
        return Answer?.Invoke(arguments) ?? (arguments[0] == "--version" ? new(0, ["v1.9.0"]) : new(0, []));
    }
}

/// <summary>Downloads: the named files' bytes (by the URL's last part; anything else = a few bytes); calls recorded.</summary>
internal sealed class FakeDownloads : IHttp
{
    public Dictionary<string, byte[]> Files { get; } = [];
    public List<string> Calls { get; } = [];

    public void Download(string url, string file)
    {
        Calls.Add(url);
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        File.WriteAllBytes(file, Files.TryGetValue(url.Split('/')[^1], out var b) ? b : [1, 2, 3]);
    }
}

internal sealed class RecordingExe : IExe
{
    public List<(string Path, string Args, bool Wait)> Calls { get; } = [];
    public Action? OnRun { get; set; }

    public ExeResult Run(string path, string arguments, bool wait = true)
    {
        Calls.Add((path, arguments, wait));
        OnRun?.Invoke();
        return new ExeResult(0, "");
    }
}
