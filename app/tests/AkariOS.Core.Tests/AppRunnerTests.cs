using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>The Runner on the four data-list kinds' Entries and on Tweaks with a Winget field, over fake packages,
/// DISM and winget (src/Core/Loader.ps1's $AkariEntryKinds and Winget rules).</summary>
public sealed class AppRunnerTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly FakePackages _pm = new();
    private readonly FakeDism _dism = new();
    private readonly FakeWingetExe _winget = new();
    private readonly MemoryLog _log = new();
    private readonly List<string> _order = [];
    private readonly MemorySourceFiles _files = new();
    private readonly Dictionary<string, ITweakCode> _codes = [];

    public void Dispose() => _key.Dispose();

    /// <summary>Before / After of a Winget Tweak, recorded in the shared order.</summary>
    private sealed class Extras(List<string> order) : ITweakCode
    {
        public void Before(Tweak tweak, TweakContext c) => order.Add("Before");
        public void After(Tweak tweak, TweakContext c, TweakMode mode) => order.Add($"After {mode}");
    }

    private (Runner Runner, Engine Engine) Make()
    {
        var reg = new RegistryEngine(_key.Paths);
        var apps = new AppPackages(_pm, _dism, _log);
        var services = new TweakServices
        {
            Apps = apps,
            Winget = new Winget(_winget, _pm, new FakeDownloads(), apps, new RecordingExe(), _log, Path.GetTempPath(), @"C:\Windows", _ => { }),
        };
        var engine = new Engine
        {
            Files = _files, Registry = reg, System = new FakeSystem(), Log = _log,
            Remembered = new JsonRememberedState(Path.Combine(Path.GetTempPath(), $"akari-apprunner-{Guid.NewGuid():N}.json")),
            Explorer = new NoExplorer(), Presets = null!, Codes = _codes, IsAdmin = () => true, Services = services,
        };
        Assert.DoesNotContain(engine.Loaded.Problems, p => p.Level == "Error");
        return (engine.Runner, engine);
    }

    private sealed class NoExplorer : IExplorer
    {
        public void Restart() { }
    }

    private static TweakGroup Group(string id, EntryKind kind, params Data.PsHashtable[] rows) =>
        new() { Id = id, Name = id, Section = "Apps", Category = kind.Button == "Install" ? "Install" : "Remove", EntryKind = kind, Source = "x", Rows = rows };

    private static AppPackage App(string name) => new(name, $"{name}_1_x64__8wekyb3d8bbwe", $"{name}_8wekyb3d8bbwe", null, false, false, false, false);

    private Outcome Run(Tweak t, TweakMode mode = TweakMode.Apply) => Make().Runner.Run(t, mode);

    [Fact]
    public void A_store_app_entry_is_removed_once()
    {
        _pm.Packages.Add(App("Microsoft.BingNews"));
        var entry = Loader.ResolveEntry([Group("appx", EntryKind.AppxRemove)], "appx/Microsoft.BingNews")!;
        Assert.Equal(new Outcome("appx/Microsoft.BingNews", TweakMode.Apply, OutcomeKind.Applied), Run(entry));
        Assert.Equal(["Microsoft.BingNews_1_x64__8wekyb3d8bbwe"], _pm.Removed);
        Assert.Equal(OutcomeKind.Already, Run(entry).Kind);
        Assert.Equal(OutcomeKind.Skipped, Run(entry, TweakMode.Revert).Kind);
    }

    [Fact]
    public void The_never_list_fails_with_why()
    {
        _pm.Packages.Add(App("Microsoft.Windows.ShellExperienceHost"));
        var entry = Loader.ResolveEntry([Group("appx", EntryKind.AppxRemove)], "appx/Microsoft.Windows.ShellExperienceHost")!;
        var o = Run(entry);
        Assert.Equal((OutcomeKind.Failed, "Microsoft.Windows.ShellExperienceHost is needed by Windows and is never removed"), (o.Kind, o.Message));
    }

    [Fact]
    public void Capabilities_and_features_go_and_want_a_restart()
    {
        _dism.Capabilities.Add(new("App.StepsRecorder~~~~0.0.1.0", "Installed"));
        _dism.Features.Add(new("WorkFolders-Client", "Enabled"));
        var cap = Loader.ResolveEntry([Group("capability", EntryKind.CapabilityRemove)], "capability/App.StepsRecorder~~~~0.0.1.0")!;
        var feat = Loader.ResolveEntry([Group("feature", EntryKind.FeatureDisable)], "feature/WorkFolders-Client")!;
        Assert.Equal(new Outcome(cap.Id, TweakMode.Apply, OutcomeKind.Applied, Reboot: true), Run(cap));
        Assert.Equal(new Outcome(feat.Id, TweakMode.Apply, OutcomeKind.Applied, Reboot: true), Run(feat));
        Assert.Equal(["remove-capability App.StepsRecorder~~~~0.0.1.0", "disable-feature WorkFolders-Client"], _dism.Changes);

        _dism.Capabilities[0] = new("App.StepsRecorder~~~~0.0.1.0", "NotPresent");
        Assert.Equal(OutcomeKind.Already, Run(cap).Kind);
    }

    [Fact]
    public void A_store_restore_installs_its_store_id_once()
    {
        _pm.Packages.Add(App("Microsoft.WindowsStore"));
        var g = Group("store", EntryKind.StoreInstall, Data.PsHashtable.Of(("Name", "Microsoft.WindowsCalculator"), ("StoreId", "9WZDNCRFHVN5")));
        var entry = Loader.ResolveEntry([g], "store/Microsoft.WindowsCalculator")!;
        Assert.Equal(OutcomeKind.Applied, Run(entry).Kind);
        Assert.Contains("install --id 9WZDNCRFHVN5 --exact --source msstore --silent --accept-package-agreements --accept-source-agreements --disable-interactivity", _winget.Calls);

        _pm.Packages.Add(App("Microsoft.WindowsCalculator"));
        Assert.Equal(OutcomeKind.Already, Run(entry).Kind);
    }

    private void Add(string id, string body, ITweakCode? code = null)
    {
        _files.Add($"src/Tweaks/Apps/Install/{id}.ps1", $$"""
            # Action: an app.
            @{ Id = '{{id}}'; Name = '{{id}}'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; Risk = 'Safe'; Description = 'x'
            {{body}}
            }
            """);
        if (code != null) _codes[id] = code;
    }

    [Fact]
    public void A_winget_app_installs_each_id_unless_all_are_there()
    {
        Add("runtimes", "Winget = 'Microsoft.VCRedist.2015+.x64', 'Microsoft.DotNet.DesktopRuntime.8'");
        var listed = new HashSet<string>();
        _winget.Answer = a => a[0] == "list" ? new(listed.Contains(a[2]) ? 0 : -1978335212, listed.Contains(a[2]) ? [a[2]] : []) : null;
        var (runner, engine) = Make();
        var t = engine.Find("runtimes")!;
        Assert.Equal(OutcomeKind.Applied, runner.Run(t, TweakMode.Apply).Kind);
        Assert.Equal(["install --id Microsoft.VCRedist.2015+.x64", "install --id Microsoft.DotNet.DesktopRuntime.8"],
            _winget.Calls.Where(c => c.StartsWith("install")).Select(c => string.Join(" ", c.Split(' ').Take(3))));

        listed.Add("Microsoft.VCRedist.2015+.x64");
        Assert.Equal(OutcomeKind.Applied, runner.Run(t, TweakMode.Apply).Kind);
        listed.Add("Microsoft.DotNet.DesktopRuntime.8");
        Assert.Equal(OutcomeKind.Already, runner.Run(t, TweakMode.Apply).Kind);
    }

    [Fact]
    public void Before_then_the_install_then_after()
    {
        Add("edge", "Winget = 'Microsoft.Edge'\nBefore = { 1 }\nAfter = { 2 }", new Extras(_order));
        _winget.Answer = a => { if (a[0] == "install") _order.Add($"install {a[2]}"); return null; };
        var (runner, engine) = Make();
        Assert.True(engine.Find("edge")!.Native);
        Assert.Equal(OutcomeKind.Applied, runner.Run(engine.Find("edge")!, TweakMode.Apply).Kind);
        Assert.Equal(["Before", "install Microsoft.Edge", "After Apply"], _order);
    }

    [Fact]
    public void A_store_app_by_winget_uses_the_msstore_source()
    {
        _pm.Packages.Add(App("Microsoft.WindowsStore"));
        Add("notepad", "Winget = '9MSMLRH6LZF3'; WingetSource = 'msstore'");
        var (runner, engine) = Make();
        Assert.Equal(OutcomeKind.Applied, runner.Run(engine.Find("notepad")!, TweakMode.Apply).Kind);
        Assert.Contains(_winget.Calls, c => c.StartsWith("list --id 9MSMLRH6LZF3 --exact --source msstore"));
        Assert.Contains(_winget.Calls, c => c.StartsWith("install --id 9MSMLRH6LZF3 --exact --source msstore"));
    }

    [Fact]
    public void A_failed_install_is_a_failed_outcome()
    {
        Add("steam", "Winget = 'Valve.Steam'");
        _winget.Answer = a => a[0] == "install" ? new(-1, ["Installer failed"]) : a[0] == "list" ? new(1, []) : null;
        var (runner, engine) = Make();
        var o = runner.Run(engine.Find("steam")!, TweakMode.Apply);
        Assert.Equal((OutcomeKind.Failed, "winget could not install Valve.Steam (0xFFFFFFFF): Installer failed"), (o.Kind, o.Message));
    }

    [Fact]
    public void Every_kind_is_native_now() =>
        Assert.Equal(EntryKind.All.Select(k => k.Name).Order(), Parity.NativeEntryKinds.Order());
}
