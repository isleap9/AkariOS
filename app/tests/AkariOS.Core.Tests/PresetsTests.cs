using System.Text.Json;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

public sealed class PresetsTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-presets-{Guid.NewGuid():N}");
    private readonly MemoryLog _log = new();
    private readonly MemorySourceFiles _builtin = new();
    private readonly PresetStore _store;

    public PresetsTests() => _store = new PresetStore(_builtin, Path.Combine(_dir, "presets"), Path.Combine(_dir, "lastused.json"), _log);

    public void Dispose()
    {
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    private static Preset P(string json) => PresetStore.Parse(json, @"C:\x\Mine.json", false);

    [Fact]
    public void Reads_every_entry_form()
    {
        var p = P("""{ "Name": "Mine", "Description": "d", "Tweaks": [ "a", { "b": "Default" }, { "c": 40, "d": "Manual" }, "appx/*" ] }""");
        Assert.Equal(("Mine", "d", false), (p.Name, p.Description, p.Builtin));
        Assert.Empty(p.Phases);
        Assert.Equal(
            [new PresetEntry("a", null, false, 0), new PresetEntry("b", "Default", true, 0), new PresetEntry("c", 40, true, 0), new PresetEntry("d", "Manual", true, 0), new PresetEntry("appx/*", null, false, 0)],
            p.Entries);
    }

    [Fact]
    public void Reads_phases_and_names_a_nameless_file_after_itself()
    {
        var p = P("""{ "Phases": [ { "Name": "Prep", "Boot": "Normal", "Tweaks": [ "a" ] }, { "Name": "Safe", "Boot": "SafeMode", "Tweaks": [ "b", "c" ] }, { "Name": "Odd", "Boot": "safe", "Tweaks": [] } ] }""");
        Assert.Equal("Mine", p.Name);
        Assert.Equal([new PresetPhase("Prep", "Normal"), new PresetPhase("Safe", "SafeMode"), new PresetPhase("Odd", "Normal")], p.Phases);
        Assert.Equal([0, 1, 1], p.Entries.Select(e => e.Phase));
    }

    [Fact]
    public void A_broken_file_is_a_warning()
    {
        Assert.Null(_store.Read("{ not json", "bad.json", false));
        Assert.Contains(_log.Lines, l => l.StartsWith("Warning: preset bad.json could not be read", StringComparison.Ordinal));
    }

    private static List<Tweak> Tweaks()
    {
        var files = new MemorySourceFiles()
            .Add("src/Tweaks/Optimize/Gaming/A.ps1", """@{ Id = 'a'; Name = 'A'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'x'; Registry = @( @{ Path = 'HKCU:\A'; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 } ) }""")
            .Add("src/Tweaks/Optimize/Gaming/B.ps1", """@{ Id = 'b'; Name = 'B'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'x'; Registry = @( @{ Path = 'HKCU:\B'; Name = 'B'; Type = 'DWord'; Value = 0; Default = 1 } ) }""")
            .Add("src/Tweaks/Optimize/Gaming/C.ps1", """
                @{ Id = 'c'; Name = 'C'; Section = 'Optimize'; Category = 'Gaming'; Kind = 'Choice'; Risk = 'Safe'; Description = 'x'
                   Registry = @{ Path = 'HKLM:\C'; Name = 'C'; Type = 'DWord' }; Choices = @( @{ Value = 0x26; Label = 's' }, @{ Value = 0x28; Label = 'f' } )
                   Recommended = 0x26; Default = 2 }
                """)
            .Add("src/Tweaks/Apps/Remove/Appx.ps1", """
                # Action: a removed app only comes back from the Store.
                @{ Id = 'appx'; Kind = 'Group'; Name = 'R'; Section = 'Apps'; Category = 'Remove'; Risk = 'Caution'; Description = 'x'; EntryKind = 'AppxRemove'
                   Entries = @( @{ Name = 'News' }, @{ Name = 'Calc'; Keep = $true }, @{ Name = 'Maps' } ) }
                """);
        var r = new Loader(files, new Dictionary<string, ITweakCode>()).Load();
        Assert.Empty(r.Problems);
        return r.Tweaks.ToList();
    }

    [Fact]
    public void Resolves_into_run_items()
    {
        var p = P("""{ "Tweaks": [ "a", { "b": "Default" }, { "c": 40 }, "appx/*", "appx/News", "missing", "a" ] }""");
        var r = PresetStore.Resolve(p, Tweaks());
        Assert.Equal(
            [new PlanItem("a", TweakMode.Apply), new PlanItem("b", TweakMode.Revert), new PlanItem("c", TweakMode.Apply, 40), new PlanItem("appx/News", TweakMode.Apply), new PlanItem("appx/Maps", TweakMode.Apply)],
            r.Items);
        Assert.Equal(["missing"], r.Unknown);
    }

    [Fact]
    public void A_choice_on_its_recommended_value_needs_no_value()
    {
        var r = PresetStore.Resolve(P("""{ "Tweaks": [ { "c": 38 } ] }"""), Tweaks());
        Assert.Equal([new PlanItem("c", TweakMode.Apply)], r.Items);
    }

    [Fact]
    public void Revert_is_reversed_and_has_no_values()
    {
        var r = PresetStore.Resolve(P("""{ "Phases": [ { "Name": "1", "Tweaks": [ "a" ] }, { "Name": "2", "Tweaks": [ { "c": 40 } ] } ] }"""), Tweaks(), revert: true);
        Assert.Equal([new PlanItem("c", TweakMode.Revert), new PlanItem("a", TweakMode.Revert)], r.Items);
    }

    [Fact]
    public void Phases_keep_their_items_and_empty_ones()
    {
        var p = P("""{ "Name": "N", "Phases": [ { "Name": "1", "Tweaks": [ "a" ] }, { "Name": "S", "Boot": "SafeMode", "Tweaks": [] }, { "Name": "3", "Tweaks": [ "b" ] } ] }""");
        var items = PresetStore.Resolve(p, Tweaks()).Items;
        var phases = PresetStore.Phases(p, items);
        Assert.Equal(["1", "S", "3"], phases.Select(x => x.Name));
        Assert.Equal("SafeMode", phases[1].Boot);
        Assert.Empty(phases[1].Items);
        Assert.Equal([new PlanItem("b", TweakMode.Apply)], phases[2].Items);
        Assert.Single(PresetStore.Phases(p, items, revert: true));
    }

    [Fact]
    public void Saves_lists_and_finds_presets()
    {
        _builtin.Add("src/Presets/AkariOS.json", """{ "Name": "AkariOS", "Tweaks": [ "a" ] }""");
        var path = _store.Save("My/Preset?", [new("a", TweakMode.Apply), new("b", TweakMode.Revert), new("c", TweakMode.Apply, 40)], "mine");
        Assert.Equal(Path.Combine(_dir, "presets", "My_Preset_.json"), path);
        Assert.Equal(["AkariOS", "My/Preset?"], _store.All().Select(p => p.Name));
        Assert.True(_store.All()[0].Builtin);
        var mine = _store.Find("my/preset?")!;
        Assert.Equal([new PresetEntry("a", null, false, 0), new PresetEntry("b", "Default", true, 0), new PresetEntry("c", 40, true, 0)], mine.Entries);
        Assert.Equal("mine", _store.Find(path)!.Description);
        Assert.Null(_store.Find("nothing"));
        Assert.Throws<ArgumentException>(() => _store.Save("  ", []));
    }

    [Fact]
    public void Last_used()
    {
        Assert.Null(_store.LastUsed());
        _store.SaveLastUsed([new("a", TweakMode.Apply)]);
        Assert.Equal(("Last used", "a"), (_store.LastUsed()!.Name, _store.LastUsed()!.Entries.Single().Id));
    }

    [Fact]
    public void Export_items_from_what_a_pc_has()
    {
        var t = Tweaks();
        Tweak T(string id) => t.First(x => x.Id == id);
        var rows = new PresetStore.ExportRow[]
        {
            new(T("a"), TweakState.Optimized, null),
            new(T("b"), TweakState.Custom, null),
            new(T("c"), TweakState.Unknown, 0x28u),
        };
        Assert.Equal([new PlanItem("a", TweakMode.Apply), new PlanItem("c", TweakMode.Apply, 0x28u)], PresetStore.ExportItems(rows, x => x.Default));
        Assert.Equal([new PlanItem("c", TweakMode.Apply)], PresetStore.ExportItems([new(T("c"), TweakState.Unknown, 38u)], x => x.Default));
        Assert.Empty(PresetStore.ExportItems([new(T("c"), TweakState.Unknown, 2u), new(T("c"), TweakState.Unknown, 99u), new(T("c"), TweakState.Unknown, null)], x => x.Default));
    }

    [Fact]
    public void Export_writes_the_pcs_settings()
    {
        using var key = new TestKey();
        var reg = new RegistryEngine(key.Paths);
        var pc = new FakeSystem();
        var states = new States(new TweakContext(reg, pc, new MemorySourceFiles()), new JsonRememberedState(Path.Combine(_dir, "state.json")));
        reg.SetValue(@"HKCU:\A", "A", 0, "DWord");
        reg.SetValue(@"HKLM:\C", "C", 0x28, "DWord");
        var file = Path.Combine(_dir, "export.json");
        var (path, count) = _store.Export(Tweaks(), states, pc, file, "1.3.0", "DESK", new DateTime(2026, 10, 31, 14, 7, 0));
        Assert.Equal((file, 2), (path, count));
        using var doc = JsonDocument.Parse(File.ReadAllText(file));
        Assert.Equal("Exported from DESK", doc.RootElement.GetProperty("Name").GetString());
        var ex = doc.RootElement.GetProperty("Exported");
        Assert.Equal(("DESK", "2026-10-31 14:07", "1.3.0", "26100"), (ex.GetProperty("Computer").GetString(), ex.GetProperty("Date").GetString(), ex.GetProperty("AkariVersion").GetString(), ex.GetProperty("WindowsBuild").GetString()));
        Assert.Equal(["a", "c"], _store.Find(file)!.Entries.Select(e => e.Id));
    }

    // ---- against the PowerShell app

    [Fact]
    public void Both_apps_read_and_resolve_presets_the_same()
    {
        Directory.CreateDirectory(_dir);
        var csFile = _store.Save("Saved by native", [new("gaming-capture-off", TweakMode.Apply), new("x", TweakMode.Revert), new("win32-priority-separation", TweakMode.Apply, 40), new("advanced-services-off", TweakMode.Apply, "Manual")], "from the native app", Path.Combine(_dir, "cs.json"));
        var psFile = Path.Combine(_dir, "ps.json");
        var ps = Oracle.Run("Export-Presets.ps1", "-Src", Repo.Src, "-CsFile", csFile, "-PsFile", psFile);

        var loaded = new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load();
        var akarios = new PresetStore(new FolderSourceFiles(Repo.Root), _store.UserFolder, _store.LastUsedPath, _log).Find("AkariOS")!;
        var apply = PresetStore.Resolve(akarios, loaded.Tweaks);
        Assert.Equal(Items(ps.GetProperty("Apply")), apply.Items.Select(Text));
        Assert.Equal(ps.GetProperty("Unknown").EnumerateArray().Select(x => x.GetString()), apply.Unknown);
        Assert.Equal(Items(ps.GetProperty("Revert")), PresetStore.Resolve(akarios, loaded.Tweaks, revert: true).Items.Select(Text));
        Assert.Equal(ps.GetProperty("Phases").EnumerateArray().Select(p => $"{p.GetProperty("Name").GetString()} {p.GetProperty("Boot").GetString()} {p.GetProperty("Count").GetInt32()}"),
            PresetStore.Phases(akarios, apply.Items).Select(p => $"{p.Name} {p.Boot} {p.Items.Count}"));
        Assert.True(apply.Items.Count > 50);

        // what the native app saved, PowerShell reads entry for entry
        Assert.Equal(("Saved by native", "from the native app"), (ps.GetProperty("CsName").GetString(), ps.GetProperty("CsDescription").GetString()));
        Assert.Equal(["gaming-capture-off   False 0", "x Default True 0", "win32-priority-separation 40 True 0", "advanced-services-off Manual True 0"],
            ps.GetProperty("CsEntries").EnumerateArray().Select(e => $"{e.GetProperty("Id").GetString()} {Plain(e.GetProperty("Value"))} {e.GetProperty("HasValue").GetBoolean()} {e.GetProperty("Phase").GetInt32()}"));

        // what PowerShell saved, the native app reads
        var fromPs = _store.Find(psFile)!;
        Assert.Equal("Saved by PowerShell", fromPs.Name);
        Assert.Equal([new PresetEntry("gaming-capture-off", null, false, 0), new PresetEntry("some-toggle", "Default", true, 0), new PresetEntry("win32-priority-separation", 40, true, 0), new PresetEntry("advanced-services-off", "Manual", true, 0)], fromPs.Entries);
    }

    private static string Plain(JsonElement v) => v.ValueKind switch
    {
        JsonValueKind.Null => " ",
        JsonValueKind.String => v.GetString()!,
        _ => v.GetRawText(),
    };

    private static IEnumerable<string> Items(JsonElement a) =>
        a.EnumerateArray().Select(i => $"{i.GetProperty("Id").GetString()} {i.GetProperty("Mode").GetString()} {Plain(i.GetProperty("Value"))} {i.GetProperty("Phase").GetInt32()}");

    private static string Text(PlanItem i) => $"{i.Id} {i.Mode} {(i.Value is null ? " " : Convert.ToString(i.Value, System.Globalization.CultureInfo.InvariantCulture))} {i.Phase}";
}
