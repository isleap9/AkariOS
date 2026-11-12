using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Apps;

/// <summary>
/// The installs with code (N5c) against their PowerShell blocks (Oracle/Invoke-TweakBlocks.ps1): a Winget Tweak's
/// Before / After, a download's Detect / Apply. The same programs run, downloads, shortcuts, waits, services,
/// processes and tasks touched, registry writes, and the same files (names and bytes) left in each side's own copy of
/// the folders.
/// </summary>
public sealed class InstallTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private readonly AppRoots _cs;
    private readonly AppRoots _ps;

    public InstallTests()
    {
        var s = _h.Engine.Services;
        _cs = new AppRoots(s.Windows, s.ProgramFiles, s.ProgramFilesX86, s.ProgramData, s.Public, _h.Folder("User"), s.LocalAppData);
        _ps = new AppRoots(_h.Folder("ps-Windows"), _h.Folder("ps-pf"), _h.Folder("ps-pf86"), _h.Folder("ps-data"), _h.Folder("ps-public"), _h.Folder("ps-user"), _h.Folder("ps-local"));
        const string folders = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders";
        _h.Set(folders, "AppData", _cs.User, "String");
        _h.Set(folders, "Local AppData", _cs.User, "String");
    }

    public void Dispose() => _h.Dispose();

    private void Files(params string[] files)
    {
        foreach (var f in files) { _cs.Add(f); _ps.Add(f); }
    }

    /// <summary>A running program, with its exe path or none.</summary>
    private void Process(string name, string? path = null)
    {
        _h.Processes.Names.Add(name);
        if (path is not null) _h.Processes.Paths[name] = path;
    }

    private JsonElement Blocks(string ids) => Oracle.Run("Invoke-TweakBlocks.ps1",
    [
        "-Src", Repo.Src, "-Ids", ids, "-TestRoot", _h.KeyRoot, "-SystemRoot", _ps.Windows, "-ProgramFiles", _ps.ProgramFiles,
        "-ProgramFilesX86", _ps.X86, "-ProgramData", _ps.ProgramData, "-Public", _ps.Public, "-UserFolder", _ps.User, "-LocalAppData", _ps.LocalAppData, "-MakeFiles",
        "-Services", Joined(_h.Services.Installed.Keys),
        "-Processes", Joined(_h.Processes.Names.Select(n => _h.Processes.Paths.TryGetValue(n, out var p) ? $"{n}={p}" : n)),
        "-Tasks", Joined(_h.Tasks.All.Keys.Select(t => $"{(t.Folder == "\\" ? "\\" : t.Folder + "\\")}|{t.Name}")),
    ]);

    // Oracle.Run never gets an empty argument
    private static string Joined(IEnumerable<string> items) => items.Any() ? string.Join(";", items) : ";";

    /// <summary>What the PowerShell block did, as comparable lines (paths as %Root%, a program by its file name).</summary>
    private List<string> PsDid(IEnumerable<string> lines) => lines.Select(l =>
    {
        var (kind, rest) = (l.Split(' ', 2)[0], l.Split(' ', 2).ElementAtOrDefault(1) ?? "");
        return kind switch
        {
            "run" => $"run {Path.GetFileName(rest.Split('|')[0])} {_ps.Vars(rest.Split('|', 2)[1])}",
            "open" => $"run {Path.GetFileName(rest)} ",
            "download" or "web" or "shortcut" or "wait" or "stop" or "stopservice" or "delservice" => $"{kind} {_ps.Vars(rest)}",
            "unregister" => $"unregister {rest.Split('|')[1]}",
            _ => null,
        };
    }).OfType<string>().Order(StringComparer.Ordinal).ToList();

    /// <summary>The same lines from the C# side's fakes.</summary>
    private List<string> CsDid()
    {
        var did = new List<string>();
        did.AddRange(_h.Exe.Full.Select(f => f.Split('|')).Select(f => $"run {Path.GetFileName(f[0])} {_cs.Vars(f[1])}"));
        did.AddRange(_h.Downloads.Saved.Select(s => $"download {_cs.Vars(s)}"));
        did.AddRange(_h.Http.Saved.Select(s => $"web {_cs.Vars(s)}"));
        did.AddRange(_h.Shortcuts.Made.Select(m => $"shortcut {Path.GetFileNameWithoutExtension(m.Key)}|{_cs.Vars(m.Value)}"));
        did.AddRange(_h.Processes.Waited.Select(w => $"wait {w}"));
        did.AddRange(_h.Processes.Stopped.Select(s => $"stop {s}"));
        did.AddRange(_h.Services.Calls.Select(c => c.StartsWith("stop ", StringComparison.Ordinal) ? $"stopservice {c[5..]}" : $"delservice {c[7..]}"));
        did.AddRange(_h.Tasks.Unregistered.Select(t => $"unregister {t.Name}"));
        return did.Order(StringComparer.Ordinal).ToList();
    }

    /// <summary>The C# side of one block against the PowerShell lines: what it did, the registry, the folders.</summary>
    private void AssertSame(List<string> ps)
    {
        Assert.Equal(PsDid(ps), CsDid());
        if (ps.Any(l => l.Split(' ')[0] is "set" or "remove" or "delkey" or "newkey")) AssertWrites(_h, ps);
        Assert.Equal(_ps.Contents(), _cs.Contents());
        Assert.Equal(_ps.Tree(), _cs.Tree());
    }

    private ITweakCode Code(string id) => _h.Engine.Codes[id];

    /// <summary>A Winget Tweak's After (Apply), C# and PowerShell.</summary>
    private void AssertSameAfter(JsonElement ps, string id)
    {
        Code(id).After(_h.Tweak(id), _h.Engine.Context, TweakMode.Apply);
        AssertSame(Lines(ps, id, "After.Apply"));
    }

    [Fact]
    public void Every_install_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Apps" && t.Category == "Install"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    private const string Run = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunLM = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    private const string Run32 = @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run";

    [Fact]
    public void The_game_launchers_stop_starting_with_windows()
    {
        _h.Set(Run, "Steam", "steam.exe -silent", "String");
        _h.Set(Run, "EADM", "ea.exe", "String");
        _h.Set(Run32, "EpicGamesLauncher", "epic.exe", "String");
        _h.Set(RunLM, "GogGalaxy", "gog.exe", "String");
        _h.Set(Run, "GalaxyClient", "gog.exe", "String");
        _h.Set(Run, "Battle.net", "bnet.exe", "String");
        _h.Set(Run, "Battle.net Updater", "bnet.exe", "String");
        _h.Set(Run, "OneDrive", "onedrive.exe", "String");
        string[] ids = ["install-steam", "install-electronic-arts", "install-epic-games", "install-gog-launcher", "install-battle-net"];
        var ps = Blocks(string.Join(",", ids));
        foreach (var id in ids) AssertSameAfter(ps, id);
        Assert.Equal("Battle.net Updater, OneDrive", string.Join(", ", _h.Engine.Registry.ValueNames(Run).Order()));
    }

    private const string ActiveSetup = @"HKLM:\Software\Microsoft\Active Setup\Installed Components";

    // the updaters of Brave, Google (Chrome) and Helium, and something else that stays
    private void Updaters()
    {
        foreach (var s in new[] { "brave", "bravem", "BraveElevationService", "gupdate", "gupdatem", "GoogleChromeElevationService", "HeliumUpdate", "Spooler" })
            _h.Services.Installed[s] = "Automatic";
        foreach (var t in new[] { "BraveSoftwareUpdateTaskMachineCore", "GoogleUpdateTaskMachineUA", "HeliumUpdater", "OneDrive Reporting Task" })
            _h.Tasks.All[new ScheduledTask("\\", t)] = true;
        _h.Set($@"{ActiveSetup}\{{8A69D345-D564-463c-AFF1-A69D9E530F96}}", "(default)", "Google Chrome", "String");
        _h.Set($@"{ActiveSetup}\{{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}}", "(default)", "Brave", "String");
        _h.Set($@"{ActiveSetup}\{{89820200-ECBD-11cf-8B85-00AA005B4340}}", "(default)", "Windows Desktop Update", "String");
    }

    [Theory]
    [InlineData("install-brave")]
    [InlineData("install-google-chrome")]
    [InlineData("install-helium")]
    public void The_chromium_browsers_get_their_policies_and_lose_their_updaters(string id)
    {
        Updaters();
        AssertSameAfter(Blocks(id), id);
        Assert.NotEmpty(_h.Services.Calls);
        Assert.NotEmpty(_h.Tasks.Unregistered);
        Assert.DoesNotContain(_h.Services.Calls, c => c.EndsWith("Spooler", StringComparison.Ordinal));
        Assert.True(_h.Engine.Registry.KeyExists($@"{ActiveSetup}\{{89820200-ECBD-11cf-8B85-00AA005B4340}}"));
    }

    [Fact]
    public void Chrome_drops_its_active_setup_entry()
    {
        Updaters();
        AssertSameAfter(Blocks("install-google-chrome"), "install-google-chrome");
        Assert.False(_h.Engine.Registry.KeyExists($@"{ActiveSetup}\{{8A69D345-D564-463c-AFF1-A69D9E530F96}}"));
        Assert.True(_h.Engine.Registry.KeyExists($@"{ActiveSetup}\{{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}}"));
    }

    [Fact]
    public void Seven_zip_gets_a_short_menu() => AssertSameAfter(Blocks("install-7-zip"), "install-7-zip");

    [Fact]
    public void Edge_and_webview2_lift_the_removals_block_first()
    {
        _h.Set(@"HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate", "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}", 0, "DWord");
        _h.Set(@"HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate", "DoNotUpdateToEdgeWithChromium", 1, "DWord");
        _h.Set(@"HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate", "Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}", 0, "DWord");
        var ps = Blocks("install-microsoft-edge,install-webview2-runtime");
        Code("install-microsoft-edge").Before(_h.Tweak("install-microsoft-edge"), _h.Engine.Context);
        AssertSame(Lines(ps, "install-microsoft-edge", "Before"));
        Assert.NotNull(_h.Get(@"HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate", "Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"));
        Code("install-webview2-runtime").Before(_h.Tweak("install-webview2-runtime"), _h.Engine.Context);
        AssertSame(Lines(ps, "install-webview2-runtime", "Before"));
    }

    [Fact]
    public void Firefox_adds_ublock_and_its_policies_and_drops_the_maintenance_service()
    {
        Files(@"%ProgramFiles(x86)%\Mozilla Maintenance Service\uninstall.exe");
        foreach (var s in new[] { "MozillaMaintenance", "Spooler" }) _h.Services.Installed[s] = "Automatic";
        _h.Tasks.All[new ScheduledTask(@"\Mozilla", "Firefox Default Browser Agent 308046B0AF4A39CB")] = true;
        _h.Set(Run, "Mozilla-Firefox-Background", "firefox.exe", "String");
        AssertSameAfter(Blocks("install-firefox"), "install-firefox");
        Assert.Contains(_h.Exe.Full, f => f.EndsWith("|/S|True|False", StringComparison.Ordinal));
        Assert.Single(_h.Http.Saved);
    }

    /// <summary>A download's Detect (not there), then its Apply through the Runner, against PowerShell's; done after.</summary>
    private void AssertSameApply(JsonElement ps, string id, bool detects = true)
    {
        if (detects)
        {
            Assert.Equal("False", Result(ps, id));
            Assert.Equal(TweakState.Default, Code(id).Detect(_h.Tweak(id), _h.Engine.Context));
        }
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        AssertSame(Lines(ps, id, "Apply"));
    }

    [Theory]
    [InlineData("install-custom-resolution-utility", 2)]
    [InlineData("install-more-clock-tool", 1)]
    [InlineData("install-nvidia-profile-inspector", 1)]
    [InlineData("install-onboard-memory-manager", 1)]
    public void A_downloaded_tool_gets_a_start_menu_shortcut(string id, int shortcuts)
    {
        AssertSameApply(Blocks(id), id);
        Assert.Equal(shortcuts, _h.Shortcuts.Made.Count);
        Assert.All(_h.Shortcuts.Made, m => Assert.Equal(Path.GetDirectoryName(m.Value), _h.Shortcuts.WorkingFolders[m.Key]));
        // the program is there now (the fake download made it): done on both sides
        var again = Blocks(id);
        Assert.Equal(("True", OutcomeKind.Already), (Result(again, id), _h.Run(id, TweakMode.Apply).Kind));
    }

    [Theory]
    [InlineData("install-remote-desktop-connection", "mstsc.exe")]
    [InlineData("install-snipping-tool-legacy", "SnippingTool.exe")]
    public void A_removed_windows_tool_comes_back_through_its_installer(string id, string exe)
    {
        AssertSameApply(Blocks(id), id);
        Assert.Equal("True|False", string.Join("|", _h.Exe.Full.Single().Split('|')[2..]));
        Files($@"%SystemRoot%\System32\{exe}");
        Assert.Equal(("True", OutcomeKind.Already), (Result(Blocks(id), id), _h.Run(id, TweakMode.Apply).Kind));
    }

    [Fact]
    public void The_nvidia_app_installs_silently()
    {
        AssertSameApply(Blocks("install-nvidia-app"), "install-nvidia-app", detects: false);
        Assert.EndsWith(@"Temp\nvidiaapp.exe|/s|True|False", _h.Exe.Full.Single());
    }

    [Theory]
    [InlineData("install-occt", @"%LOCALAPPDATA%\Microsoft\WinGet\Packages\OCBase.OCCT.Personal_Microsoft.Winget.Source_8wekyb3d8bbwe\OCCTPersonal.exe")]
    [InlineData("install-rufus", @"%ProgramFiles%\WinGet\Packages\Rufus.Rufus_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\rufus-4.6.exe")]
    public void A_portable_winget_package_gets_a_start_menu_shortcut(string id, string exe)
    {
        Files(exe, @"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Other.App_Microsoft.Winget.Source_8wekyb3d8bbwe\OCCT-old.exe");
        AssertSameAfter(Blocks(id), id);
        Assert.Single(_h.Shortcuts.Made);
    }

    [Fact]
    public void A_portable_package_not_found_makes_no_shortcut()
    {
        AssertSameAfter(Blocks("install-occt"), "install-occt");
        Assert.Empty(_h.Shortcuts.Made);
    }

    [Fact]
    public void Discord_waits_for_its_own_installer_then_gets_its_settings()
    {
        Process("Update", @"C:\Users\me\AppData\Local\Discord\Update.exe");
        Process("Discord");
        _h.Set(Run, "Discord", "Update.exe --processStart Discord.exe", "String");
        AssertSameAfter(Blocks("install-discord"), "install-discord");
        Assert.Equal(["Update|300"], _h.Processes.Waited);
        Assert.True(File.Exists(Path.Combine(_cs.User, @"discord\settings.json")));
    }

    [Fact]
    public void Discord_leaves_another_apps_updater_alone()
    {
        Process("Update", @"C:\Program Files\Other\Update.exe");
        AssertSameAfter(Blocks("install-discord"), "install-discord");
        Assert.Empty(_h.Processes.Waited);
    }

    [Fact]
    public void Spotify_writes_its_prefs_and_installs_as_the_user_through_explorer()
    {
        Process("SpotifySetup");
        AssertSameApply(Blocks("install-spotify"), "install-spotify");
        Assert.Equal(["SpotifySetup|600"], _h.Processes.Waited);
        Assert.EndsWith(@"\explorer.exe|""" + Path.Combine(_cs.Public, @"Downloads\SpotifySetup.exe") + @"""|False|True", _h.Exe.Full.Single());
        _cs.Add(@"%User%\Spotify\Spotify.exe");
        Assert.Equal(OutcomeKind.Already, _h.Run("install-spotify", TweakMode.Apply).Kind);
    }

    [Fact]
    public void Notepad_plus_plus_gets_akaris_config()
    {
        _cs.Add(@"%User%\Notepad++\config.xml");
        _ps.Add(@"%User%\Notepad++\config.xml");
        AssertSameAfter(Blocks("install-notepad"), "install-notepad");
        Assert.NotEmpty(File.ReadAllBytes(Path.Combine(_cs.User, @"Notepad++\config.xml")));
    }

    [Fact]
    public void Afterburner_gets_akaris_profiles_and_overlay()
    {
        Files(@"%ProgramFiles(x86)%\MSI Afterburner\MSIAfterburner.exe", @"%ProgramFiles(x86)%\RivaTuner Statistics Server\Profiles\Config");
        AssertSameAfter(Blocks("msi-afterburner"), "msi-afterburner");
        Assert.True(File.Exists(Path.Combine(_cs.X86, @"RivaTuner Statistics Server\Plugins\Client\Overlays\akarios.ovl")));
    }

    [Fact]
    public void The_microsoft_store_comes_back_registered_from_the_disk()
    {
        var store = _h.Folder("Store");
        File.WriteAllText(Path.Combine(store, "AppxManifest.xml"), "<Package/>");
        var pm = new StorePackages(store);
        var log = new Core.MemoryLog();
        var apps = new Core.Apps.AppPackages(pm, new NoDism(), log);
        var services = _h.Engine.Services;
        var c = new TweakContext(_h.Engine.Registry, _h.Pc, _h.Engine.Files, log, new TweakServices
        {
            Apps = apps,
            Winget = new Core.Apps.Winget(new NoWinget(), pm, _h.Http, apps, _h.Exe, log, _h.Folder("temp"), services.Windows, _ => { }),
        });
        var code = Code("install-microsoft-store");
        var t = _h.Tweak("install-microsoft-store");
        Assert.Equal(TweakState.Default, code.Detect(t, c));
        code.Apply(t, c, null);
        Assert.Equal([$@"register {store}\AppxManifest.xml"], pm.Calls);
        Assert.Equal(TweakState.Optimized, code.Detect(t, c));
    }

    /// <summary>The Store's files on the disk, not registered for the user; registering its manifest brings it back.</summary>
    private sealed class StorePackages(string folder) : Core.Apps.IPackageManager
    {
        private bool _registered;
        public List<string> Calls { get; } = [];
        private Core.Apps.AppPackage Store(string name) =>
            new(name, $"{name}_22410.1401.6.0_x64__8wekyb3d8bbwe", $"{name}_8wekyb3d8bbwe", folder, false, false, false, false);
        public IReadOnlyList<Core.Apps.AppPackage> AllUsers() => _registered ? [Store("Microsoft.WindowsStore")] : [Store("Microsoft.WindowsStoreLeftover")];
        public void Register(string manifest) { Calls.Add($"register {manifest}"); _registered = true; }
        public void Remove(string fullName) => Calls.Add($"remove {fullName}");
        public void RegisterByFamily(string family) => Calls.Add($"register-family {family}");
        public void Add(string file) => Calls.Add($"add {file}");
        public IReadOnlyList<Core.Apps.ProvisionedApp> ProvisionedApps() => [];
        public void Deprovision(string family) => Calls.Add($"deprovision {family}");
    }

    private sealed class NoDism : Core.Apps.IDism
    {
        public IReadOnlyList<Core.Apps.DismItem> Capabilities() => [];
        public IReadOnlyList<Core.Apps.DismItem> Features() => [];
        public string? CapabilityState(string name) => null;
        public string? FeatureState(string name) => null;
        public void RemoveCapability(string name) { }
        public void DisableFeature(string name) { }
    }

    private sealed class NoWinget : Core.Apps.IWinget
    {
        public Core.Apps.WingetResult Run(params string[] arguments) => throw new InvalidOperationException("winget is not needed here");
    }

    [Fact]
    public void Firefox_without_the_maintenance_service_runs_nothing()
    {
        AssertSameAfter(Blocks("install-firefox"), "install-firefox");
        Assert.Empty(_h.Exe.Full);
    }
}
