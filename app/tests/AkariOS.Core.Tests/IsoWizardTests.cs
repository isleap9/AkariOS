using AkariOS.Core.Iso;
using AkariOS.Core.Presets;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using static AkariOS.Core.Tests.IsoBuildOracleTests;

namespace AkariOS.Core.Tests;

/// <summary>The ISO Builder wizard's modes and removal groups (batch I4, native only): the data, the AkariOS bake, the
/// first sign-in, and a build from groups instead of zISO's always-on data.</summary>
public sealed class IsoWizardTests
{
    private static readonly FolderSourceFiles Files = new(Repo.Root);

    private static readonly Lazy<IReadOnlyList<Tweak>> Loaded =
        new(() => new Loader(Files, new Dictionary<string, ITweakCode>()).Load().Tweaks);

    private static Preset AkariOSPreset() => new PresetStore(Files, Path.GetTempPath(), Path.Combine(Path.GetTempPath(), "none.json"), new MemoryLog())
        .Find(IsoWizard.Preset)!;

    [Fact]
    public void Reads_the_modes_and_their_groups()
    {
        var groups = IsoWizard.Groups(Files);
        var modes = IsoWizard.Modes(Files);
        Assert.Equal(["AkariOS", "Lite"], modes.Select(m => m.Id));
        Assert.Equal([true, false], modes.Select(m => m.AkariOS));
        Assert.Equal(["Recommended", "Update-safe"], modes.Select(m => m.Tag));
        Assert.All(modes, m => Assert.Equal(IsoCompression.Maximum, m.Settings.Compression));
        // every mode's groups exist, both skip the hardware checks
        Assert.All(modes, m => Assert.Equal(m.Groups.Count, IsoWizard.Picked(m.Groups, groups).Count));
        Assert.All(modes, m => Assert.Contains("SkipHardwareChecks", m.Groups));
        Assert.Equal(groups.Select(g => g.Order).Order(), groups.Select(g => g.Order));
        Assert.All(groups, g => Assert.False(string.IsNullOrEmpty(g.Name) || string.IsNullOrEmpty(g.Description)));
        // rows name a hive the build loads
        Assert.All(groups.SelectMany(g => g.Registry.Concat(g.Boot)), r => IsoData.Rows([r], IsoData.HiveRoot));
        Assert.Throws<IsoException>(() => IsoWizard.Picked(["Nope"], groups));
    }

    [Fact]
    public void The_akarios_modes_app_pick_is_the_akarios_presets()
    {
        // the preset removes the appx Group's non-keep Entries ("appx/*"); the mode's group expands to the same names
        var preset = AkariOSPreset();
        Assert.Contains(preset.Entries, e => e.Id == "appx/*");
        var mode = IsoWizard.Modes(Files).Single(m => m.Id == "AkariOS");
        var groups = IsoWizard.Picked(mode.Groups, IsoWizard.Groups(Files));
        var tweaks = Loaded.Value.Select(t => (t.Id, (string?)t.Risk.ToString(), t.Keep)).ToList();
        var resolved = PresetStore.Resolve(preset, Loaded.Value).Items.Where(i => i.Id.StartsWith("appx/", StringComparison.Ordinal)).Select(i => i.Id[5..]);
        var patterns = IsoWizard.AppPatterns(groups.Where(g => g.Apps.Any(a => a.StartsWith("appx:", StringComparison.Ordinal))), tweaks);
        Assert.Equal(resolved.Order(StringComparer.Ordinal), patterns.Order(StringComparer.Ordinal));
        Assert.NotEmpty(patterns);
    }

    [Fact]
    public void Expands_the_appx_tokens_and_keeps_other_patterns()
    {
        (string, string?, bool)[] tweaks = [("appx/A", "Safe", false), ("appx/B", "Caution", false), ("appx/C", "Safe", true), ("other", "Safe", false)];
        IsoGroup G(params string[] apps) => new("g", "g", "", "Apps", "Safe", 0, apps, [], [], [], [], [], [], []);
        Assert.Equal(["A"], IsoWizard.AppPatterns([G("appx:Safe")], tweaks));
        Assert.Equal(["A", "B"], IsoWizard.AppPatterns([G("appx:AkariOS")], tweaks));
        Assert.Equal(["A", "B", "Edge*"], IsoWizard.AppPatterns([G("appx:Safe", "appx:AkariOS"), G("Edge*", "a")], tweaks));
    }

    [Theory]
    [InlineData(@"HKLM:\SOFTWARE\Policies\X", @"HKLM:\AkariIso_SOFTWARE\Policies\X")]
    [InlineData(@"HKLM:\SYSTEM\CurrentControlSet\Services\X", @"HKLM:\AkariIso_SYSTEM\ControlSet001\Services\X")]
    [InlineData(@"HKLM:\SYSTEM\Setup", @"HKLM:\AkariIso_SYSTEM\Setup")]
    [InlineData(@"HKCU:\Control Panel\Mouse", @"HKLM:\AkariIso_NTUSER\Control Panel\Mouse")]
    [InlineData(@"Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard", @"HKLM:\AkariIso_DEFAULT\Control Panel\Keyboard")]
    [InlineData(@"HKEY_CLASSES_ROOT\Directory", @"HKLM:\AkariIso_SOFTWARE\Classes\Directory")]
    [InlineData(@"HKCU:\Software\Classes\CLSID\{x}", null)]
    [InlineData(@"HKLM:\HARDWARE\X", null)]
    [InlineData(@"Registry::HKEY_USERS\S-1-5-21-1\X", null)]
    [InlineData("not a path", null)]
    public void Puts_a_tweaks_path_in_the_image_or_nowhere(string path, string? expected) => Assert.Equal(expected, IsoWizard.ImagePath(path));

    [Fact]
    public void Bakes_the_akarios_presets_registry_only_tweaks_and_leaves_the_rest_for_the_first_sign_in()
    {
        var bake = IsoWizard.Bake(AkariOSPreset(), Loaded.Value, 26100);
        Assert.NotEmpty(bake.InImage);
        Assert.All(bake.InImage, i =>
        {
            Assert.Empty(i.Tweak.Blocks);
            Assert.False(i.Tweak.SafeMode);
            Assert.Null(i.Tweak.EntryKind);
            Assert.All(i.Tweak.Registry!, r => Assert.NotNull(IsoWizard.ImagePath(r.Path)));
            if (i.Tweak.Kind == TweakKind.Choice) Assert.NotNull(i.Value);
        });
        // script blocks, Safe Mode, installs and removals run at the first sign-in
        Assert.Contains("oneclick-ddu-prepare", bake.Later);
        Assert.Contains("security-defender-settings", bake.Later);
        Assert.Contains(bake.Later, id => id.StartsWith("appx/", StringComparison.Ordinal));
        // everything the preset names is in one list or the other
        var all = PresetStore.Resolve(AkariOSPreset(), Loaded.Value).Items.Select(i => i.Id);
        Assert.Equal(all.Order(StringComparer.Ordinal), bake.InImage.Select(i => i.Tweak.Id).Concat(bake.Later).Order(StringComparer.Ordinal));
    }

    [Fact]
    public void Bakes_by_the_images_windows()
    {
        var t = Toggle("t-win10", [Row(@"HKLM:\SOFTWARE\X", "A")]) ;
        var win10 = new Tweak { Id = "w10", Name = "w10", Section = "S", Category = "C", Source = "s", Requires = ["Win10"], Registry = t.Registry };
        var laptop = new Tweak { Id = "lap", Name = "lap", Section = "S", Category = "C", Source = "s", Requires = ["Laptop"], Registry = t.Registry };
        var preset = new Preset("p", "", [new("w10", null, false, 0), new("lap", null, false, 0)], [], "", true);
        Assert.Equal(["lap"], IsoWizard.Bake(preset, [win10, laptop], 19045).Later);
        Assert.Equal(["w10", "lap"], IsoWizard.Bake(preset, [win10, laptop], 26100).Later);
    }

    // ---- the build

    private static RegistryRow Row(string path, string name, object? value = null) =>
        new(path, name, "DWord", value ?? 1, OsValue.Both(null), false);

    private static Tweak Toggle(string id, IReadOnlyList<RegistryRow> rows) =>
        new() { Id = id, Name = id, Section = "Optimize", Category = "Test", Source = "test", Registry = rows };

    [Fact]
    public void Builds_from_the_groups_instead_of_the_always_on_data()
    {
        var c = Case(x => x["ImageFiles"] = (string[])[.. ImageFiles, @"Windows\System32\OneDriveSetup.exe"]);
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => fakes = f, ch => ch with { Groups = ["SkipHardwareChecks", "OneDrive"], AppPatterns = ["Microsoft.BingNews"] });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        var reg = fakes!.Parts.Registry;
        Assert.Equal(1u, reg.GetValue(@"HKLM:\AkariIso_SYSTEM\Setup\LabConfig", "BypassTPMCheck"));
        Assert.Equal(1u, reg.GetValue(@"HKLM:\AkariIso_SOFTWARE\Policies\Microsoft\Windows\OneDrive", "DisableFileSyncNGSC"));
        // zISO's always-on rows and paths are not written or removed
        Assert.Null(reg.GetValue(@"HKLM:\AkariIso_SOFTWARE\Policies\Microsoft\Windows\CloudContent", "DisableWindowsConsumerFeatures"));
        Assert.DoesNotContain(fakes.Ops, x => x.Name == @"Windows\InboxApps");
        Assert.Contains(fakes.Ops, x => x.Name == @"Windows\System32\OneDriveSetup.exe" && x.State == IsoOpState.Done);
        // the app pattern matched on the image
        Assert.Contains(fakes.Ops, x => x.Name == "App Microsoft.BingNews" && x.State != IsoOpState.Running);
        Assert.Contains("Skipping the Windows 11 requirements in setup (boot.wim)", o.Log);
    }

    [Fact]
    public void A_wizard_build_without_settings_groups_has_no_settings_files_or_boot_steps()
    {
        var steps = IsoPlan.Steps(new IsoChoices { Groups = [] }, [], []).Select(x => x.Id).ToList();
        Assert.DoesNotContain("Registry", steps);
        Assert.DoesNotContain("Files", steps);
        Assert.DoesNotContain("Boot", steps);
        Assert.DoesNotContain("Bake", steps);
        // the port's build keeps them all
        var port = IsoPlan.Steps(new IsoChoices(), []).Select(x => x.Id).ToList();
        Assert.Contains("Registry", port);
        Assert.Contains("Files", port);
        Assert.Contains("Boot", port);
    }

    [Fact]
    public void An_unknown_group_fails_the_build_before_it_starts()
    {
        var c = Case();
        using var s = new Side(c);
        var o = Cs(s, c, null, ch => ch with { Groups = ["Nope"] });
        Assert.Equal("Action=Build;Ok=false;Path=;Message=Unknown removal group: Nope", o.Results[1]);
    }

    [Fact]
    public void Writes_the_baked_tweaks_into_the_image_and_the_first_sign_in_runonce()
    {
        var c = Case(x => Choices(x)["AkariOS"] = true);
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var toggle = Toggle("t-user", [Row(@"HKCU:\Control Panel\Mouse", "MouseSpeed", 0), Row(@"HKLM:\SYSTEM\CurrentControlSet\Control\X", "Y", 2)]);
        var choice = new Tweak
        {
            Id = "t-choice", Name = "A choice", Section = "Optimize", Category = "Test", Source = "test", Kind = TweakKind.Choice,
            Registry = [Row(@"HKLM:\SOFTWARE\Policies\Z", "Level")], Recommended = 3,
        };
        var o = Cs(s, c, f => fakes = f, ch => ch with
        {
            Groups = [], Bake = [new(toggle, null), new(choice, 5)], FirstSignIn = true, ImageBuild = 26100,
        });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        var reg = fakes!.Parts.Registry;
        Assert.Equal(0u, reg.GetValue(@"HKLM:\AkariIso_NTUSER\Control Panel\Mouse", "MouseSpeed"));
        Assert.Equal(2u, reg.GetValue(@"HKLM:\AkariIso_SYSTEM\ControlSet001\Control\X", "Y"));
        Assert.Equal(5u, reg.GetValue(@"HKLM:\AkariIso_SOFTWARE\Policies\Z", "Level"));
        Assert.Equal(IsoWizard.FirstSignInCommand, reg.GetValue(IsoData.HiveRoot + IsoWizard.RunOnceKey, IsoWizard.RunOnceName));
        Assert.Contains("-ArgumentList '--first-sign-in' -Verb RunAs", IsoWizard.FirstSignInCommand);
        Assert.Contains(@"'C:\AkariOS\AkariOS-Native.exe'", IsoWizard.FirstSignInCommand);
        Assert.Contains("Writing the AkariOS settings into the image", o.Log);
        var ended = fakes.Ops.Where(x => x.State != IsoOpState.Running).Select(x => (x.Name, x.State)).ToList();
        Assert.Contains(("Tweak t-user", IsoOpState.Done), ended);
        Assert.Contains(("Tweak A choice", IsoOpState.Done), ended);
        Assert.Contains(("The rest of AkariOS at the first sign-in", IsoOpState.Done), ended);
        // the hives loaded for the bake are unloaded after it
        Assert.Equal(fakes.Calls.Count(x => x.StartsWith("HiveLoad", StringComparison.Ordinal)), fakes.Calls.Count(x => x.StartsWith("HiveUnload", StringComparison.Ordinal)));
    }

    [Fact]
    public void Leaves_the_first_sign_in_out_without_the_exe()
    {
        var steps = IsoPlan.Steps(new IsoChoices { Groups = [], FirstSignIn = true }, [], []).Select(x => x.Id);
        Assert.DoesNotContain("Bake", steps);
        steps = IsoPlan.Steps(new IsoChoices { Groups = [], FirstSignIn = true, AkariExe = "x.exe" }, [], []).Select(x => x.Id).ToList();
        Assert.Contains("Bake", steps);
        Assert.True(steps.ToList().IndexOf("Bake") < steps.ToList().IndexOf("Commit"));
    }
}
