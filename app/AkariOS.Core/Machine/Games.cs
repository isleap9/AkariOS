using System.Text;
using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Machine;

/// <summary>A game found (Get-AkariGames): Key = its exe path in lower case; Source Steam | Epic | GOG | Added.</summary>
public sealed record GameInfo(string Key, string Name, string Exe, string Source, bool Gpu, bool Fso, bool Priority)
{
    public bool Get(string setting) => setting switch { "Gpu" => Gpu, "Fso" => Fso, "Priority" => Priority, _ => false };
}

/// <summary>A game added by hand (games.json).</summary>
public sealed record OwnGame(string Name, string Exe);

/// <summary>Where the launchers keep their lists (Get-AkariGameSources): Steam's folder, Epic's manifests, GOG's key,
/// games.json.</summary>
public sealed record GameSources(string Steam, string Epic, string Gog, string Own);

/// <summary>Where the three switches live (src/Core/Games.ps1's $AkariGamePaths; tests: a test key).</summary>
public sealed record GamePaths(string Gpu, string Layers, string Ifeo)
{
    public static GamePaths Windows { get; } = new(@"HKCU:\Software\Microsoft\DirectX\UserGpuPreferences",
        @"HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers",
        @"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options");
}

/// <summary>
/// Per-game settings (src/Core/Games.ps1, plan 2026-11-26-new-features.md X5): the games on this PC and three switches
/// each, every one a single value that Off removes: High-performance GPU (UserGpuPreferences), Fullscreen optimizations
/// off (the DISABLEDXMAXIMIZEDWINDOWEDMODE layer, others kept), High CPU priority (IFEO PerfOptions, per exe name).
/// The pure parts are compared with the PowerShell app's by GamesTests.
/// </summary>
public sealed class Games(RegistryEngine registry, GameSources sources, GamePaths? paths = null)
{
    public const string GpuValue = "GpuPreference=2;";
    public const string FsoFlag = "DISABLEDXMAXIMIZEDWINDOWEDMODE";
    public static readonly string[] Settings = ["Gpu", "Fso", "Priority"];

    public static readonly string[] ExeSkip =
    [
        "unins*", "*crash*", "*setup*", "*install*", "*redist*", "vc_*", "dxsetup*", "*helper*", "*report*",
        "*updater*", "*update.exe", "*service*", "easyanticheat*", "beservice*", "battleye*", "*launcherpatcher*", "dotnet*", "ue4prereq*", "cefsharp*",
    ];

    private GamePaths P => paths ?? GamePaths.Windows;

    /// <summary>The real places: the real user's Steam, Epic's manifests under ProgramData, GOG's key, the app's own
    /// games.json.</summary>
    public static GameSources Live(RegistryEngine registry, TweakServices services, string own) => new(
        (PsSemantics.Text(registry.GetValue(@"HKCU:\Software\Valve\Steam", "SteamPath")) ?? "").Replace('/', '\\'),
        services.ProgramData.Length > 0 ? Path.Combine(services.ProgramData, @"Epic\EpicGamesLauncher\Data\Manifests") : "",
        @"HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games", own);

    /// <summary>Read-AkariVdf (pure): Valve's KeyValues as nested dictionaries (keys as written, case-insensitive).</summary>
    public static Dictionary<string, object> Vdf(string text)
    {
        var root = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        var stack = new Stack<Dictionary<string, object>>();
        var cur = root;
        string? key = null;
        var i = 0;
        while (i < text.Length)
        {
            var c = text[i];
            if (c == '"')
            {
                var sb = new StringBuilder();
                i++;
                while (i < text.Length && text[i] != '"')
                {
                    if (text[i] == '\\' && i + 1 < text.Length) { i++; sb.Append(text[i] switch { 'n' => '\n', 't' => '\t', var e => e }); }
                    else sb.Append(text[i]);
                    i++;
                }
                i++;
                var s = sb.ToString();
                if (key is null) key = s; else { cur[key] = s; key = null; }
            }
            else if (c == '{')
            {
                var child = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                if (key is not null) cur[key] = child;
                stack.Push(cur); cur = child; key = null; i++;
            }
            else if (c == '}')
            {
                if (stack.Count > 0) cur = stack.Pop();
                key = null; i++;
            }
            else if (c == '/' && i + 1 < text.Length && text[i + 1] == '/') { while (i < text.Length && text[i] != '\n') i++; }
            else i++;
        }
        return root;
    }

    /// <summary>Select-AkariGameExe (pure): the game's exe among (relative path, size): skips <see cref="ExeSkip"/>; the
    /// biggest wins, then the shallowest, then by name. '' when none.</summary>
    public static string PickExe(IEnumerable<(string Path, long Size)> files)
    {
        (string Path, long Size)? best = null;
        foreach (var f in files)
        {
            if (!f.Path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) continue;
            var name = System.IO.Path.GetFileName(f.Path);
            if (ExeSkip.Any(p => PsSemantics.Like(name, p))) continue;
            if (best is not { } b) { best = f; continue; }
            var (d, bd) = (f.Path.Split('\\').Length, b.Path.Split('\\').Length);
            if (f.Size > b.Size || (f.Size == b.Size && (d < bd || (d == bd && string.Compare(f.Path, b.Path, StringComparison.OrdinalIgnoreCase) < 0)))) best = f;
        }
        return best?.Path ?? "";
    }

    /// <summary>Set-AkariLayerFlag (pure): the Layers value with the flag on or off; '' = none left.</summary>
    public static string SetLayer(string? data, string flag, bool on)
    {
        var parts = (data ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries).Where(p => p != "~" && !p.Equals(flag, StringComparison.OrdinalIgnoreCase)).ToList();
        if (on) parts.Add(flag);
        return parts.Count == 0 ? "" : "~ " + string.Join(' ', parts);
    }

    /// <summary>Test-AkariLayerFlag (pure).</summary>
    public static bool HasLayer(string? data, string flag) =>
        (data ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries).Contains(flag, StringComparer.OrdinalIgnoreCase);

    /// <summary>Get-AkariFolderExes: an exe's files up to three folders down, relative.</summary>
    public static IReadOnlyList<(string Path, long Size)> FolderExes(string folder)
    {
        var list = new List<(string, long)>();
        if (string.IsNullOrEmpty(folder) || !Directory.Exists(folder)) return list;
        var root = folder.TrimEnd('\\').Length + 1;
        void Walk(string dir, int depth)
        {
            try { foreach (var f in Directory.GetFiles(dir, "*.exe")) list.Add((f[root..], new FileInfo(f).Length)); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
            if (depth < 3)
                try { foreach (var d in Directory.GetDirectories(dir)) Walk(d, depth + 1); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        }
        Walk(folder, 0);
        return list;
    }

    /// <summary>Get-AkariOwnGames.</summary>
    public IReadOnlyList<OwnGame> Own()
    {
        try
        {
            if (!File.Exists(sources.Own)) return [];
            var j = JsonDocument.Parse(File.ReadAllText(sources.Own)).RootElement;
            var items = j.ValueKind == JsonValueKind.Array ? j.EnumerateArray().ToList() : [j];
            return items.Where(x => x.ValueKind == JsonValueKind.Object && x.TryGetProperty("Exe", out var e) && e.GetString() is { Length: > 0 })
                .Select(x => new OwnGame(x.TryGetProperty("Name", out var n) ? n.GetString() ?? "" : "", x.GetProperty("Exe").GetString()!)).ToList();
        }
        catch (Exception e) when (e is IOException or JsonException or InvalidOperationException) { return []; }
    }

    /// <summary>Save-AkariOwnGames.</summary>
    public void SaveOwn(IEnumerable<OwnGame> games)
    {
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(sources.Own)!);
        File.WriteAllText(sources.Own, JsonSerializer.Serialize(games.Select(g => new { g.Name, g.Exe }), new JsonSerializerOptions { WriteIndented = true }));
    }

    /// <summary>Get-AkariGames: every game, one per exe, by name then exe.</summary>
    public IReadOnlyList<GameInfo> All()
    {
        var found = new List<(string Name, string Exe, string Source)>();
        if (sources.Steam.Length > 0)
        {
            var libs = new List<string> { sources.Steam };
            var lf = System.IO.Path.Combine(sources.Steam, @"steamapps\libraryfolders.vdf");
            if (File.Exists(lf) && Vdf(File.ReadAllText(lf)).GetValueOrDefault("libraryfolders") is Dictionary<string, object> top)
                foreach (var v in top.Values)
                    if (v is Dictionary<string, object> lib && lib.GetValueOrDefault("path") is string p) libs.Add(p);
            foreach (var lib in libs.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                var apps = System.IO.Path.Combine(lib, "steamapps");
                if (!Directory.Exists(apps)) continue;
                foreach (var m in Directory.GetFiles(apps, "appmanifest_*.acf"))
                {
                    if (Vdf(File.ReadAllText(m)).GetValueOrDefault("AppState") is not Dictionary<string, object> st || st.GetValueOrDefault("installdir") is not string dir) continue;
                    var folder = System.IO.Path.Combine(apps, "common", dir);
                    var exe = PickExe(FolderExes(folder));
                    if (exe.Length > 0) found.Add((st.GetValueOrDefault("name") as string ?? "", System.IO.Path.Combine(folder, exe), "Steam"));
                }
            }
        }
        if (sources.Epic.Length > 0 && Directory.Exists(sources.Epic))
            foreach (var m in Directory.GetFiles(sources.Epic, "*.item"))
            {
                try
                {
                    var j = JsonDocument.Parse(File.ReadAllText(m)).RootElement;
                    string S(string n) => j.TryGetProperty(n, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";
                    if (S("InstallLocation").Length > 0 && S("LaunchExecutable").Length > 0)
                        found.Add((S("DisplayName"), System.IO.Path.Combine(S("InstallLocation"), S("LaunchExecutable")), "Epic"));
                }
                catch (Exception e) when (e is IOException or JsonException) { }
            }
        if (sources.Gog.Length > 0)
            foreach (var id in registry.SubKeys(sources.Gog))
                if (PsSemantics.Text(registry.GetValue($@"{sources.Gog}\{id}", "exe")) is { Length: > 0 } exe)
                    found.Add((PsSemantics.Text(registry.GetValue($@"{sources.Gog}\{id}", "gameName")) ?? "", exe, "GOG"));
        foreach (var g in Own()) found.Add((g.Name, g.Exe, "Added"));
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var list = new List<GameInfo>();
        foreach (var (name, exe, source) in found)
        {
            var key = exe.ToLowerInvariant();
            if (!seen.Add(key)) continue;
            var (gpu, fso, prio) = SettingsOf(exe);
            list.Add(new GameInfo(key, name.Length > 0 ? name : System.IO.Path.GetFileNameWithoutExtension(exe), exe, source, gpu, fso, prio));
        }
        var byName = StringComparer.Create(System.Globalization.CultureInfo.CurrentCulture, ignoreCase: true);
        return list.OrderBy(g => g.Name, byName).ThenBy(g => g.Exe, byName).ToList();
    }

    private string Perf(string exe) => $@"{P.Ifeo}\{System.IO.Path.GetFileName(exe)}\PerfOptions";

    /// <summary>Get-AkariGameSettings.</summary>
    public (bool Gpu, bool Fso, bool Priority) SettingsOf(string exe) => (
        (PsSemantics.Text(registry.GetValue(P.Gpu, exe)) ?? "").Contains(GpuValue, StringComparison.OrdinalIgnoreCase),
        HasLayer(PsSemantics.Text(registry.GetValue(P.Layers, exe)), FsoFlag),
        registry.GetValue(Perf(exe), "CpuPriorityClass") is uint u && u == 3);

    /// <summary>Set-AkariGameSetting: one switch; throws when it stays as it was.</summary>
    public void Set(string exe, string setting, bool on)
    {
        switch (setting)
        {
            case "Gpu":
                if (on) registry.SetValue(P.Gpu, exe, GpuValue, "String"); else registry.RemoveValue(P.Gpu, exe);
                break;
            case "Fso":
                var d = SetLayer(PsSemantics.Text(registry.GetValue(P.Layers, exe)), FsoFlag, on);
                if (d.Length > 0) registry.SetValue(P.Layers, exe, d, "String"); else registry.RemoveValue(P.Layers, exe);
                break;
            case "Priority":
                if (on) registry.SetValue(Perf(exe), "CpuPriorityClass", 3, "DWord"); else registry.RemoveValue(Perf(exe), "CpuPriorityClass");
                break;
            default: throw new ArgumentException($"No game setting '{setting}'");
        }
        var now = SettingsOf(exe);
        var value = setting switch { "Gpu" => now.Gpu, "Fso" => now.Fso, _ => now.Priority };
        if (value != on) throw new InvalidOperationException($"Windows keeps it {(on ? "off" : "on")}");
    }
}
