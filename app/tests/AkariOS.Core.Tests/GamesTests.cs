using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Tests;

/// <summary>
/// Per-game settings (X5): the pure parts against src\Core\Games.ps1 (Oracle/Export-Games.ps1), then the games found
/// from fake Steam, Epic, GOG and games.json sources and the three switches on a test key. No real launcher or value.
/// </summary>
public sealed class GamesTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-games-{Guid.NewGuid():N}");

    public GamesTests() => Directory.CreateDirectory(_dir);

    public void Dispose()
    {
        _key.Dispose();
        Directory.Delete(_dir, true);
    }

    private static readonly string[] Vdfs =
    [
        "\"libraryfolders\"\n{\n    // a comment\n    \"0\" { \"path\"  \"C:\\\\Program Files (x86)\\\\Steam\" \"apps\" { \"730\" \"123\" } }\n    \"1\"\n    {\n        \"path\"\t\t\"D:\\\\Games\\\\Steam\"\n    }\n}\n",
        "\"AppState\" { \"appid\" \"1\" \"name\" \"Tab\\tName \\\"Q\\\"\" \"installdir\" \"Alpha\" }",
        "",
        "\"unclosed\" { \"a\" \"b\"",
    ];

    private static readonly (string Path, long Size)[][] Exes =
    [
        [("unins000.exe", 900), ("UnityCrashHandler64.exe", 800), ("Game.exe", 500), (@"bin\x64\Game-Win64.exe", 700), ("readme.txt", 9999)],
        [(@"b\Same.exe", 5), ("Same.exe", 5)],
        [(@"z\A.exe", 5), (@"y\B.exe", 5)],
        [("vc_redist.x64.exe", 5), ("EasyAntiCheat_Setup.exe", 9)],
        [],
    ];

    private static readonly (string Data, string Flag, bool On)[] Layers =
    [
        ("", Games.FsoFlag, true), ("~ RUNASADMIN", Games.FsoFlag, true), ($"~ RUNASADMIN {Games.FsoFlag}", Games.FsoFlag, false),
        ($"~ {Games.FsoFlag}", Games.FsoFlag, false), ("RUNASADMIN", Games.FsoFlag, false), ($"~  {Games.FsoFlag}  HIGHDPIAWARE", Games.FsoFlag, true),
    ];

    private static string Format(Dictionary<string, object> d, string prefix) =>
        string.Join("\n", d.SelectMany(p => p.Value is Dictionary<string, object> c
            ? new[] { $"{prefix}{p.Key}/" }.Concat(Format(c, $"{prefix}{p.Key}/") is { Length: > 0 } s ? s.Split('\n') : [])
            : [$"{prefix}{p.Key}={p.Value}"]));

    [Fact]
    public void The_pure_parts_are_powershells()
    {
        var cases = Path.Combine(_dir, "cases.json");
        File.WriteAllText(cases, JsonSerializer.Serialize(new
        {
            Vdf = Vdfs,
            Exe = Exes.Select(set => set.Select(f => new { f.Path, f.Size })),
            Layers = Layers.Select(l => new { l.Data, l.Flag, l.On }),
        }));
        var ps = Oracle.Run("Export-Games.ps1", "-Src", Repo.Src, "-Cases", cases);
        Assert.Equal(ps.GetProperty("Vdf").EnumerateArray().Select(e => e.GetString()), Vdfs.Select(v => Format(Games.Vdf(v), "")));
        Assert.Equal(ps.GetProperty("Exe").EnumerateArray().Select(e => e.GetString()), Exes.Select(e => Games.PickExe(e)));
        Assert.Equal(ps.GetProperty("Layers").EnumerateArray().Select(e => e.GetString()),
            Layers.Select(l => $"{Games.SetLayer(l.Data, l.Flag, l.On)}|{(Games.HasLayer(l.Data, l.Flag) ? "True" : "False")}"));
    }

    [Fact]
    public void Finds_the_launchers_games_and_switches_each_setting_as_one_value()
    {
        var steam = Path.Combine(_dir, "Steam");
        Directory.CreateDirectory(Path.Combine(steam, @"steamapps\common\Alpha\bin"));
        File.WriteAllText(Path.Combine(steam, @"steamapps\libraryfolders.vdf"), $"\"libraryfolders\" {{ \"0\" {{ \"path\" \"{steam.Replace(@"\", @"\\")}\" }} }}");
        File.WriteAllText(Path.Combine(steam, @"steamapps\appmanifest_1.acf"), "\"AppState\" { \"appid\" \"1\" \"name\" \"Alpha\" \"installdir\" \"Alpha\" }");
        File.WriteAllBytes(Path.Combine(steam, @"steamapps\common\Alpha\bin\alpha.exe"), new byte[64]);
        File.WriteAllBytes(Path.Combine(steam, @"steamapps\common\Alpha\unins000.exe"), new byte[128]);
        var epic = Path.Combine(_dir, "Epic");
        Directory.CreateDirectory(epic);
        File.WriteAllText(Path.Combine(epic, "x.item"), """{ "DisplayName": "Beta", "InstallLocation": "E:\\Beta", "LaunchExecutable": "Beta.exe" }""");
        var reg = new RegistryEngine(_key.Paths);
        reg.SetValue(@"HKLM:\GOG\1", "gameName", "Gamma", "String");
        reg.SetValue(@"HKLM:\GOG\1", "exe", @"G:\Gamma\gamma.exe", "String");
        var games = new Games(reg, new GameSources(steam, epic, @"HKLM:\GOG", Path.Combine(_dir, "games.json")));
        games.SaveOwn([new OwnGame("Delta", @"H:\delta.exe"), new OwnGame("Again", @"E:\Beta\Beta.exe")]);

        var all = games.All();
        Assert.Equal(["Alpha:Steam", "Beta:Epic", "Delta:Added", "Gamma:GOG"], all.Select(g => $"{g.Name}:{g.Source}"));
        Assert.Equal(Path.Combine(steam, @"steamapps\common\Alpha\bin\alpha.exe"), all[0].Exe);
        Assert.Equal(@"e:\beta\beta.exe", all[1].Key);

        const string exe = @"C:\Games\Zeta\zeta.exe";
        var p = GamePaths.Windows;
        reg.SetValue(p.Layers, exe, "~ RUNASADMIN", "String");
        foreach (var s in Games.Settings) games.Set(exe, s, true);
        Assert.Equal((true, true, true), games.SettingsOf(exe));
        Assert.Equal(Games.GpuValue, reg.GetValue(p.Gpu, exe));
        Assert.Equal($"~ RUNASADMIN {Games.FsoFlag}", reg.GetValue(p.Layers, exe));
        Assert.Equal(3u, reg.GetValue($@"{p.Ifeo}\zeta.exe\PerfOptions", "CpuPriorityClass"));
        foreach (var s in Games.Settings) games.Set(exe, s, false);
        Assert.Null(reg.GetValue(p.Gpu, exe));
        Assert.Equal("~ RUNASADMIN", reg.GetValue(p.Layers, exe));
        Assert.Null(reg.GetValue($@"{p.Ifeo}\zeta.exe\PerfOptions", "CpuPriorityClass"));
    }
}
