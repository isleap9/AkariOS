using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

public sealed class StatesTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _stateFile = Path.Combine(Path.GetTempPath(), $"akari-state-{Guid.NewGuid():N}", "state.json");
    private readonly FakeSystem _system = new() { Build = 26100 };
    private readonly RegistryEngine _reg;
    private readonly States _states;

    public StatesTests()
    {
        _reg = new RegistryEngine(_key.Paths);
        _states = new States(new TweakContext(_reg, _system, new MemorySourceFiles()), new JsonRememberedState(_stateFile));
    }

    public void Dispose()
    {
        _key.Dispose();
        if (Directory.Exists(Path.GetDirectoryName(_stateFile))) Directory.Delete(Path.GetDirectoryName(_stateFile)!, recursive: true);
    }

    internal sealed class FakeSystem : ISystemInfo
    {
        public int Build { get; set; }
    }

    private sealed class Code : ITweakCode
    {
        public Func<TweakState>? OnDetect { get; init; }
        public Func<object?>? OnValue { get; init; }
        public Func<IReadOnlyList<RegistryRow>>? OnRows { get; init; }
        public TweakState Detect(Tweak tweak, TweakContext c) => OnDetect!();
        public object? ChoiceValue(Tweak tweak, TweakContext c) => OnValue!();
        public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => OnRows!();
    }

    private static Tweak Load(string body, ITweakCode? code = null, string kind = "", string head = "")
    {
        var text = $$"""
            {{head}}
            @{ Id = 't'; Name = 'T'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'x'{{kind}}
            {{body}}
            }
            """;
        var codes = code is null ? new Dictionary<string, ITweakCode>() : new Dictionary<string, ITweakCode> { ["t"] = code };
        var r = new Loader(new MemorySourceFiles().Add("src/Tweaks/Optimize/Gaming/T.ps1", text), codes).Load();
        Assert.DoesNotContain(r.Problems, p => p.Level == "Error");
        return Assert.Single(r.Tweaks);
    }

    private const string Rows = """
        Registry = @(
            @{ Path = 'HKCU:\Software\Akari'; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 }
            @{ Path = 'HKCU:\Software\Akari'; Name = 'B'; Type = 'String'; Value = 'x'; Default = $null }
        )
        """;

    [Fact]
    public void An_action_has_no_state() =>
        Assert.Equal(TweakState.Unknown, _states.Of(Load("Apply = { 1 }", kind: "; Kind = 'Action'", head: "# Action: one shot.")));

    [Fact]
    public void Registry_rows_give_the_state()
    {
        var t = Load(Rows);
        Assert.Equal(TweakState.Custom, _states.Of(t));
        _reg.Invoke(t.Registry!, TweakMode.Apply, 26100);
        Assert.Equal(TweakState.Optimized, _states.Of(t));
        _reg.Invoke(t.Registry!, TweakMode.Revert, 26100);
        Assert.Equal(TweakState.Default, _states.Of(t));
    }

    [Fact]
    public void Detect_is_the_tweaks_csharp()
    {
        var detect = Rows.Replace("Registry = @(", "Detect = { $true }\n    Registry = @(");
        Assert.Equal(TweakState.Optimized, _states.Of(Load(detect, new Code { OnDetect = () => TweakState.Optimized })));
        Assert.Equal(TweakState.Unknown, _states.Of(Load(detect, new Code { OnDetect = () => throw new IOException("no") })));
        // no C# for it: the native app can't read it
        Assert.Equal(TweakState.Unknown, _states.Of(Load(detect)));
    }

    private const string Choice = """
        Registry    = @{ Path = 'HKLM:\SYSTEM\Akari'; Name = 'Prio'; Type = 'DWord' }
        Choices     = @(
            @{ Value = 0x26; Label = 'short' }
            @{ Value = 0x18; Label = 'long' }
        )
        Recommended = 0x26
        Default     = 2
        """;

    [Fact]
    public void A_choice_compares_its_value()
    {
        var t = Load(Choice, kind: "; Kind = 'Choice'");
        // missing, with a Default that is set: can't tell
        Assert.Equal(TweakState.Unknown, _states.Of(t));
        _reg.SetValue(@"HKLM:\SYSTEM\Akari", "Prio", 0x26, "DWord");
        Assert.Equal(TweakState.Optimized, _states.Of(t));
        Assert.Equal(38u, _states.ChoiceValue(t));
        _reg.SetValue(@"HKLM:\SYSTEM\Akari", "Prio", 2, "DWord");
        Assert.Equal(TweakState.Default, _states.Of(t));
        _reg.SetValue(@"HKLM:\SYSTEM\Akari", "Prio", 0x18, "DWord");
        Assert.Equal(TweakState.Custom, _states.Of(t));

        // missing with a Default of $null: that is the Default
        var none = Load(Choice.Replace("Default     = 2", "Default     = $null"), kind: "; Kind = 'Choice'");
        _reg.RemoveValue(@"HKLM:\SYSTEM\Akari", "Prio");
        Assert.Equal(TweakState.Default, _states.Of(none));
    }

    [Fact]
    public void A_per_os_default_follows_the_build()
    {
        var t = Load(Choice.Replace("Default     = 2", "Default     = @{ Win10 = 2; Win11 = 0x18 }"), kind: "; Kind = 'Choice'");
        _reg.SetValue(@"HKLM:\SYSTEM\Akari", "Prio", 0x18, "DWord");
        Assert.Equal(TweakState.Default, _states.Of(t));
        _system.Build = 19045;
        Assert.Equal(TweakState.Custom, _states.Of(t));
        Assert.Equal(2, _states.DefaultFor(t));
    }

    [Fact]
    public void A_choice_over_many_settings_reads_its_csharp()
    {
        var body = """
            Value       = { Get-ServicePick }
            Apply       = { Set-ServicePick $AkariValue }
            Revert      = { Set-ServicePick 'Default' }
            Choices     = @( @{ Value = 'Off'; Label = 'Off' }, @{ Value = 'Default'; Label = 'Windows default' } )
            Recommended = 'Off'
            Default     = 'Default'
            """;
        Assert.Equal(TweakState.Optimized, _states.Of(Load(body, new Code { OnValue = () => "off" }, kind: "; Kind = 'Choice'")));
        Assert.Equal(TweakState.Default, _states.Of(Load(body, new Code { OnValue = () => "Default" }, kind: "; Kind = 'Choice'")));
        // none of its values
        Assert.Equal(TweakState.Custom, _states.Of(Load(body, new Code { OnValue = () => null }, kind: "; Kind = 'Choice'")));
        Assert.Equal(TweakState.Unknown, _states.Of(Load(body, kind: "; Kind = 'Choice'")));
    }

    [Fact]
    public void Rows_built_by_code_come_from_its_csharp()
    {
        var body = """
            Registry = @(
                @{ Path = 'HKCU:\Software\Akari'; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 }
                foreach ($p in 'x', 'y') { @{ Path = "HKCU:\Software\Akari\$p"; Name = 'V'; Type = 'DWord'; Value = 0; Default = 1 } }
            )
            """;
        var rows = new[] { "", @"\x", @"\y" }.Select(s => new RegistryRow($@"HKCU:\Software\Akari{s}", s == "" ? "A" : "V", "DWord", 0, OsValue.Both(1), false)).ToList();
        var t = Load(body, new Code { OnRows = () => rows });
        Assert.True(t.RowsAreCode);
        _reg.Invoke(rows, TweakMode.Revert, 26100);
        Assert.Equal(TweakState.Default, _states.Of(t));
        _reg.SetValue(@"HKCU:\Software\Akari\y", "V", 0, "DWord");
        Assert.Equal(TweakState.Custom, _states.Of(t));
        Assert.Equal(TweakState.Unknown, _states.Of(Load(body)));
    }

    [Fact]
    public void Without_anything_to_read_it_is_what_akari_last_did()
    {
        var t = Load("Apply = { 1 }; Revert = { 2 }", new Code());
        Assert.Equal(TweakState.Unknown, _states.Of(t));
        var remembered = new JsonRememberedState(_stateFile);
        remembered.Set("t", true);
        Assert.Equal(TweakState.Optimized, _states.Of(t));
        remembered.Set("t", false);
        Assert.Equal(TweakState.Default, _states.Of(t));
    }

    [Fact]
    public void State_json_is_the_powershell_apps_format()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_stateFile)!);
        File.WriteAllText(_stateFile, "{\r\n    \"hardware-rebar-force\":  true,\r\n    \"x\":  false\r\n}");
        var s = new JsonRememberedState(_stateFile);
        Assert.True(s.Get("hardware-rebar-force"));
        Assert.False(s.Get("X"));
        Assert.Null(s.Get("other"));
        File.WriteAllText(_stateFile, "not json");
        Assert.Null(s.Get("x"));
        s.Set("y", true);
        Assert.True(new JsonRememberedState(_stateFile).Get("y"));
    }

    [Fact]
    public void Every_real_tweak_reads_a_state_on_an_empty_registry()
    {
        var loaded = new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load();
        var states = new States(new TweakContext(_reg, _system, new FolderSourceFiles(Repo.Root)), new JsonRememberedState(_stateFile));
        var counts = loaded.Tweaks.GroupBy(states.Of).ToDictionary(g => g.Key, g => g.Count());
        // nothing is set: only a Tweak whose every row deletes something is Optimized (already applied)
        var optimized = loaded.Tweaks.Where(t => states.Of(t) == TweakState.Optimized).Select(t => t.Id).ToList();
        var deleting = loaded.Tweaks.Where(t => t.Kind == TweakKind.Toggle && !t.NeedsCode && t.Registry is { Count: > 0 } rows && rows.All(r => r.Value is null)).Select(t => t.Id).ToList();
        Assert.Equal(deleting, optimized);
        Assert.NotEmpty(deleting);
        Assert.True(counts.GetValueOrDefault(TweakState.Default) > 50);
    }
}
