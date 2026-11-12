using AkariOS.Core.Apps;

namespace AkariOS.Core.Tests;

/// <summary>Store apps, Optional features and Windows features (src/Core/Appx.ps1) over a fake package manager and a
/// fake DISM: nothing real is read or removed.</summary>
public sealed class AppPackagesTests : IDisposable
{
    private readonly FakePackages _pm = new();
    private readonly FakeDism _dism = new();
    private readonly MemoryLog _log = new();
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-appx-{Guid.NewGuid():N}");

    public void Dispose()
    {
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    private AppPackages Make() => new(_pm, _dism, _log);

    private static AppPackage App(string name, string? user = null, bool framework = false, bool resource = false, bool nonRemovable = false, bool system = false, string? location = null) =>
        new(name, $"{name}_1.0.0.0_x64__8wekyb3d8bbwe{user}", $"{name}_8wekyb3d8bbwe", location, framework, resource, nonRemovable, system);

    [Fact]
    public void Installed_leaves_out_what_cant_or_mustnt_go()
    {
        _pm.Packages.AddRange([
            App("Microsoft.BingNews"), App("Microsoft.BingNews", user: "_b"), App("Clipchamp.Clipchamp"),
            App("Microsoft.VCLibs.140.00", framework: true), App("Microsoft.LanguageExperiencePackfr-FR", resource: true),
            App("Microsoft.XboxGameCallableUI", nonRemovable: true), App("Microsoft.Windows.Search", system: true),
            App("MicrosoftWindows.Client.CBS"), App("Microsoft.Windows.ShellExperienceHost"), App("windows.immersivecontrolpanel"),
            App("Microsoft.Windows.StartMenuExperienceHost"),
        ]);
        Assert.Equal(["Clipchamp.Clipchamp", "Microsoft.BingNews"], Make().Installed());
        Assert.Equal(["Microsoft.BingNews"], Make().Installed([App("Microsoft.BingNews"), App("Microsoft.VCLibs.140.00", framework: true)]));
        Assert.True(Make().IsInstalled("Microsoft.VCLibs.140.00"));
        Assert.False(Make().IsInstalled("Microsoft.Todos"));
    }

    [Theory]
    [InlineData("MicrosoftWindows.Client.CBS", true)]
    [InlineData("Microsoft.Windows.ShellExperienceHost", true)]
    [InlineData("WINDOWS.IMMERSIVECONTROLPANEL", true)]
    [InlineData("Microsoft.BingNews", false)]
    public void The_never_list(string name, bool never) => Assert.Equal(never, AppPackages.IsNever(name));

    [Fact]
    public void Remove_takes_it_from_every_user_then_its_provisioned_copy()
    {
        _pm.Packages.AddRange([App("Microsoft.BingNews"), App("Microsoft.BingNews", user: "_b"), App("Microsoft.Todos")]);
        _pm.Provisioned.AddRange([new("Microsoft.BingNews", "Microsoft.BingNews_8wekyb3d8bbwe"), new("Microsoft.Todos", "Microsoft.Todos_8wekyb3d8bbwe")]);
        Make().Remove("Microsoft.BingNews");
        Assert.Equal(["Microsoft.BingNews_1.0.0.0_x64__8wekyb3d8bbwe", "Microsoft.BingNews_1.0.0.0_x64__8wekyb3d8bbwe_b"], _pm.Removed);
        Assert.Equal(["deprovision Microsoft.BingNews_8wekyb3d8bbwe"], _pm.Changes);
    }

    [Fact]
    public void A_failed_removal_fails_and_a_failed_deprovision_is_only_logged()
    {
        _pm.Packages.Add(App("Microsoft.BingNews"));
        _pm.Fail = new InvalidOperationException("0x80073CFA: removal failed");
        Assert.Equal("0x80073CFA: removal failed", Assert.Throws<InvalidOperationException>(() => Make().Remove("Microsoft.BingNews")).Message);

        _pm.Fail = null;
        _pm.Provisioned.Add(new("Microsoft.BingNews", "p"));
        _pm.DeprovisionFail = new InvalidOperationException("busy");
        Make().Remove("Microsoft.BingNews");
        Assert.Contains("Microsoft.BingNews: its provisioned copy stays (busy)", _log.Lines);
    }

    [Fact]
    public void The_never_list_is_never_removed()
    {
        _pm.Packages.Add(App("Microsoft.Windows.ShellExperienceHost"));
        var e = Assert.Throws<InvalidOperationException>(() => Make().Remove("Microsoft.Windows.ShellExperienceHost"));
        Assert.Equal("Microsoft.Windows.ShellExperienceHost is needed by Windows and is never removed", e.Message);
        Assert.Empty(_pm.Removed);
    }

    [Fact]
    public void Capabilities_and_features()
    {
        _dism.Capabilities.AddRange([new("App.StepsRecorder~~~~0.0.1.0", "Installed"), new("Media.WindowsMediaPlayer~~~~0.0.12.0", "Installed"), new("Language.Basic~~~fr-FR~0.0.1.0", "NotPresent"), new("App.StepsRecorder~~~~0.0.1.0", "Installed")]);
        _dism.Features.AddRange([new("WorkFolders-Client", "Enabled"), new("Printing-XPSServices-Features", "Enabled"), new("TelnetClient", "Disabled")]);
        var a = Make();
        Assert.Equal(["App.StepsRecorder~~~~0.0.1.0", "Media.WindowsMediaPlayer~~~~0.0.12.0"], a.InstalledCapabilities());
        Assert.Equal(["Printing-XPSServices-Features", "WorkFolders-Client"], a.EnabledFeatures());
        Assert.True(a.CapabilityInstalled("App.StepsRecorder~~~~0.0.1.0"));
        Assert.False(a.CapabilityInstalled("Language.Basic~~~fr-FR~0.0.1.0"));
        Assert.False(a.CapabilityInstalled("Nope"));
        Assert.True(a.FeatureEnabled("WorkFolders-Client"));
        Assert.False(a.FeatureEnabled("TelnetClient"));
        a.RemoveCapability("App.StepsRecorder~~~~0.0.1.0");
        a.DisableFeature("WorkFolders-Client");
        Assert.Equal(["remove-capability App.StepsRecorder~~~~0.0.1.0", "disable-feature WorkFolders-Client"], _dism.Changes);
    }

    private string Package(string name, string manifest, params string[] files)
    {
        var dir = Path.Combine(_dir, name);
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, "AppxManifest.xml"), manifest);
        foreach (var f in files)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(Path.Combine(dir, f))!);
            File.WriteAllBytes(Path.Combine(dir, f), [1]);
        }
        return dir;
    }

    private static string Manifest(string? square, string? logo) => $$"""
        <?xml version="1.0" encoding="utf-8"?>
        <Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10" xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10">
          <Properties>{{(logo is null ? "" : $"<Logo>{logo}</Logo>")}}</Properties>
          <Applications><Application Id="App">{{(square is null ? "" : $"<uap:VisualElements Square44x44Logo=\"{square}\" />")}}</Application></Applications>
        </Package>
        """;

    [Fact]
    public void Logos_prefer_an_unplated_48_px_app_icon()
    {
        var news = Package("News", Manifest(@"Assets\Square44.png", @"Assets\Store.png"),
            @"Assets\Square44.targetsize-32.png", @"Assets\Square44.targetsize-48_altform-unplated.png", @"Assets\Store.png");
        var store = Package("Store", Manifest(null, @"Assets\Store.png"), @"Assets\Store.scale-100.png", @"Assets\Store.scale-200.png");
        var plain = Package("Plain", Manifest(@"Assets\Icon.png", null), @"Assets\Icon.png");
        var odd = Package("Odd", Manifest(@"Assets\Icon.png", null), @"Assets\Icon.contrast-white_targetsize-16.png");
        var none = Package("None", Manifest(@"Missing\Icon.png", null));
        var logos = AppPackages.Logos([
            App("News", location: news), App("News", user: "_b", location: _dir), App("Store", location: store), App("Plain", location: plain),
            App("Odd", location: odd), App("None", location: none), App("Gone", location: Path.Combine(_dir, "gone")), App("NoFolder"),
        ]);
        Assert.Equal(Path.Combine(news, @"Assets\Square44.targetsize-48_altform-unplated.png"), logos["News"]);
        Assert.Equal(Path.Combine(store, @"Assets\Store.scale-200.png"), logos["Store"]);
        Assert.Equal(Path.Combine(plain, @"Assets\Icon.png"), logos["Plain"]);
        Assert.Equal(Path.Combine(odd, @"Assets\Icon.contrast-white_targetsize-16.png"), logos["Odd"]);
        Assert.Equal(["News", "Odd", "Plain", "Store"], logos.Keys.Order(StringComparer.Ordinal));
    }

    [Theory]
    [InlineData(0, "NotPresent", "Disabled")]
    [InlineData(1, "UninstallPending", "DisablePending")]
    [InlineData(2, "Staged", "Disabled")]
    [InlineData(3, "Removed", "DisabledWithPayloadRemoved")]
    [InlineData(4, "Installed", "Enabled")]
    [InlineData(5, "InstallPending", "EnablePending")]
    [InlineData(6, "Superseded", "Superseded")]
    [InlineData(7, "PartiallyInstalled", "PartiallyInstalled")]
    public void Dism_states_read_as_the_cmdlets_name_them(int state, string capability, string feature)
    {
        Assert.Equal(capability, DismApi.CapabilityStateName(state));
        Assert.Equal(feature, DismApi.FeatureStateName(state));
    }

    [Fact]
    public void The_real_ones_cant_be_made_in_a_test()
    {
        Assert.Throws<InvalidOperationException>(() => new WindowsPackages());
        Assert.Throws<InvalidOperationException>(() => new DismApi());
    }
}

/// <summary>A package manager with a list of packages; removals and registrations recorded.</summary>
internal sealed class FakePackages : IPackageManager
{
    public List<AppPackage> Packages { get; } = [];
    public List<ProvisionedApp> Provisioned { get; } = [];
    public List<string> Removed { get; } = [];
    public List<string> Changes { get; } = [];
    public Exception? Fail { get; set; }
    public Exception? DeprovisionFail { get; set; }

    public IReadOnlyList<ProvisionedApp> ProvisionedApps() => Provisioned.ToList();

    public void Deprovision(string family)
    {
        if (DeprovisionFail is not null) throw DeprovisionFail;
        Changes.Add($"deprovision {family}");
    }

    /// <summary>What a registration or an Add does to the list (e.g. the Store or App Installer appears).</summary>
    public Action<string>? OnChange { get; set; }

    public IReadOnlyList<AppPackage> AllUsers() => Packages.ToList();

    public void Remove(string fullName)
    {
        if (Fail is not null) throw Fail;
        Removed.Add(fullName);
        Packages.RemoveAll(p => p.FullName == fullName);
    }

    public void RegisterByFamily(string family) => Change($"register-family {family}");
    public void Register(string manifest) => Change($"register {manifest}");
    public void Add(string file) => Change($"add {file}");

    private void Change(string what)
    {
        Changes.Add(what);
        OnChange?.Invoke(what);
        if (Fail is not null) throw Fail;
    }
}

/// <summary>DISM with lists of capabilities and features; changes recorded.</summary>
internal sealed class FakeDism : IDism
{
    public List<DismItem> Capabilities { get; } = [];
    public List<DismItem> Features { get; } = [];
    public List<string> Changes { get; } = [];

    IReadOnlyList<DismItem> IDism.Capabilities() => Capabilities.ToList();
    IReadOnlyList<DismItem> IDism.Features() => Features.ToList();
    public string? CapabilityState(string name) => Capabilities.FirstOrDefault(c => c.Name == name)?.State;
    public string? FeatureState(string name) => Features.FirstOrDefault(f => f.Name == name)?.State;
    public void RemoveCapability(string name) => Changes.Add($"remove-capability {name}");
    public void DisableFeature(string name) => Changes.Add($"disable-feature {name}");
}
