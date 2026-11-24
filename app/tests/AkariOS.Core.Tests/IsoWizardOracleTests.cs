using System.Globalization;
using System.Text.Json;
using AkariOS.Core.Iso;
using AkariOS.Core.Presets;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>The ISO Builder wizard's pure parts (PowerShell catch-up P7): the native IsoWizard and IsoPlan.Steps against
/// src\Core\Iso.ps1 and Iso\Image.ps1 on the same Wizard data, real Tweaks and AkariOS preset
/// (Oracle/Export-IsoWizard.ps1): the groups and modes, each mode's app patterns and plan, image paths, the bake.</summary>
public sealed class IsoWizardOracleTests
{
    private static readonly FolderSourceFiles Files = new(Repo.Root);

    private static readonly string[] Paths =
    [
        @"HKLM:\SOFTWARE\Policies\X", @"HKLM:\SYSTEM\CurrentControlSet\Services\X", @"HKLM:\SYSTEM\Setup", @"HKLM:\SYSTEM", @"HKLM:\SOFTWAREX\Y",
        @"HKCU:\Control Panel\Mouse", @"HKCU:\Software\Classes\CLSID\{x}", @"HKCU:\Software\ClassesX", @"Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard",
        @"Registry::HKEY_USERS\S-1-5-21-1\X", @"HKEY_CLASSES_ROOT\Directory", @"HKEY_LOCAL_MACHINE\SOFTWARE\Z", @"HKEY_LOCAL_MACHINE:\SOFTWARE\Z",
        @"HKLM:\HARDWARE\X", @"HKCC:\X", "not a path", @"HKLM:\SOFTWARE\Policies\X\",
    ];

    private static readonly int[] Builds = [26100, 22631, 19045];

    private static readonly Lazy<JsonElement> Ps = new(() =>
    {
        var dir = Path.Combine(Path.GetTempPath(), $"akari-wizard-oracle-{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        var paths = Path.Combine(dir, "paths.txt");
        var builds = Path.Combine(dir, "builds.txt");
        File.WriteAllLines(paths, Paths);
        File.WriteAllLines(builds, Builds.Select(b => b.ToString(CultureInfo.InvariantCulture)));
        try { return Oracle.Run("Export-IsoWizard.ps1", "-Src", Repo.Src, "-Paths", paths, "-Builds", builds); }
        finally { Directory.Delete(dir, true); }
    });

    private static readonly Lazy<IReadOnlyList<Tweak>> Loaded = new(() => new Loader(Files, new Dictionary<string, ITweakCode>()).Load().Tweaks);

    private static Preset AkariOSPreset() => new PresetStore(Files, Path.GetTempPath(), Path.Combine(Path.GetTempPath(), "none.json"), new MemoryLog())
        .Find(IsoWizard.Preset)!;

    private static JsonElement P(string name) => Ps.Value.GetProperty(name);
    private static string[] Texts(JsonElement e) => [.. e.EnumerateArray().Select(x => x.GetString() ?? "")];
    private static string Show(object? v) => v is null ? "" : v is bool b ? (b ? "True" : "False") : Convert.ToString(v, CultureInfo.InvariantCulture) ?? "";
    private static IEnumerable<(string, string?, bool)> AppTweaks() => Loaded.Value.Select(t => (t.Id, (string?)t.Risk.ToString(), t.Keep));

    [Fact]
    public void The_groups_and_modes_are_read_the_same_in_order()
    {
        string L(IEnumerable<string> v) => string.Join(";", v);
        var groups = IsoWizard.Groups(Files).Select(g =>
            $"{g.Id}|{g.Name}|{g.Description}|{g.Kind}|{g.Risk}|{g.Order}|{L(g.Apps)}|{L(g.Features)}|{L(g.Capabilities)}|{L(g.Packages)}|{g.Registry.Count}|{L(g.RemoveKeys)}|{L(g.Remove)}|{g.Boot.Count}|{(g.PruneComponentStore ? "True" : "False")}");
        Assert.Equal(Texts(P("Groups")), groups);
        var modes = IsoWizard.Modes(Files).Select(m =>
            $"{m.Id}|{m.Name}|{m.Description}|{m.Tag}|{m.Order}|{L(m.Groups)}|{m.Settings.Compression}|{Show(m.Settings.Turbo)}|{Show(m.Settings.CleanLeftovers)}|{Show(m.Settings.LeaveOutNetFx3Files)}|{Show(m.AkariOS)}|{Show(m.Minimal)}");
        Assert.Equal(Texts(P("Modes")), modes);
        Assert.Equal("Unknown removal group: Nope", P("Unknown").GetString());
    }

    [Fact]
    public void Each_modes_app_patterns_and_plan_are_the_same()
    {
        var all = IsoWizard.Groups(Files);
        var modes = IsoWizard.Modes(Files);
        var patterns = P("Patterns").EnumerateArray().ToList();
        var plans = P("Plans").EnumerateArray().ToList();
        Assert.Equal(modes.Count, plans.Count);
        for (var i = 0; i < modes.Count; i++)
        {
            var m = modes[i];
            // Minimal prunes the component store: the PowerShell app has it in batch P9
            if (m.Minimal) continue;
            var picked = IsoWizard.Picked(m.Groups, all);
            var apps = IsoWizard.AppPatterns(picked, AppTweaks());
            Assert.Equal(Texts(patterns[i]), apps);
            var c = new IsoChoices { Edition = "Windows 11 Pro", Groups = [.. m.Groups], AppPatterns = [.. apps], Settings = m.Settings };
            if (m.AkariOS) c = c with { AkariExe = @"C:\AkariOS\AkariOS-Native.exe", FirstSignIn = true, Bake = IsoWizard.Bake(AkariOSPreset(), Loaded.Value, 26100).InImage };
            Assert.Equal(Texts(plans[i]), IsoPlan.Steps(c, [], picked).Select(s => $"{s.Id}|{s.Text}"));
        }
    }

    [Fact]
    public void Tweak_paths_land_in_the_same_place_in_the_image() =>
        Assert.Equal(Texts(P("ImagePaths")), Paths.Select(p => IsoWizard.ImagePath(p) ?? "(none)"));

    [Fact]
    public void The_akarios_preset_bakes_the_same_for_each_windows()
    {
        var bakes = P("Bakes").EnumerateArray().ToList();
        for (var i = 0; i < Builds.Length; i++)
        {
            var b = IsoWizard.Bake(AkariOSPreset(), Loaded.Value, Builds[i]);
            var ps = Texts(bakes[i].GetProperty("InImage"));
            var cs = b.InImage.Select(x => $"{x.Tweak.Id}={Show(x.Value)}").ToList();
            Assert.Equal(ps, cs);
            Assert.Equal(Texts(bakes[i].GetProperty("Later")), b.Later);
        }
    }
}
