using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Presets;

/// <summary>One entry of a preset: "id" (Apply), { "id": value } (a Choice value, or "Default" = Revert), "group/*".</summary>
public sealed record PresetEntry(string Id, object? Value, bool HasValue, int Phase);

/// <summary>A phase of a preset (Boot Normal or SafeMode): a Run in steps across restarts.</summary>
public sealed record PresetPhase(string Name, string Boot);

/// <summary>A preset file read (Read-AkariPreset). Phases: none for a flat "Tweaks" list.</summary>
public sealed record Preset(string Name, string Description, IReadOnlyList<PresetEntry> Entries, IReadOnlyList<PresetPhase> Phases, string Path, bool Builtin);

/// <summary>A preset resolved into Run items, and the ids it names that aren't loaded here.</summary>
public sealed record Resolved(IReadOnlyList<PlanItem> Items, IReadOnlyList<string> Unknown);

/// <summary>A phase of the Run a preset makes (Get-AkariPresetPhases).</summary>
public sealed record RunPhase(string Name, string Boot, IReadOnlyList<PlanItem> Items);

/// <summary>
/// Presets (src/Core/Presets.ps1, docs/PLAN.md §8), the same JSON both apps read and write: built-in ones from
/// src/Presets, the user's in %LOCALAPPDATA%\Akari\presets (shared with the PowerShell app), Last used (the native
/// app's own lastused.json). Resolve, Phases and the export conversion are pure.
/// </summary>
public sealed class PresetStore(ISourceFiles builtin, string userFolder, string lastUsedPath, IAkariLog log)
{
    public string UserFolder { get; } = userFolder;
    public string LastUsedPath { get; } = lastUsedPath;

    // ---- reading

    /// <summary>A preset's JSON text -> the preset, or null (the warning is logged).</summary>
    public Preset? Read(string text, string path, bool isBuiltin)
    {
        try { return Parse(text, path, isBuiltin); }
        catch (Exception e) when (e is JsonException or InvalidOperationException or FormatException)
        {
            log.Write($"Warning: preset {path} could not be read ({e.Message})");
            return null;
        }
    }

    public static Preset Parse(string text, string path, bool isBuiltin)
    {
        var j = JsonNode.Parse(text.TrimStart('﻿')) as JsonObject ?? throw new FormatException("not a JSON object");
        var phasesNode = Get(j, "Phases") as JsonArray;
        var groups = phasesNode is { Count: > 0 } ? phasesNode.Select(p => p as JsonObject).ToList() : [j];
        var phases = new List<PresetPhase>();
        var entries = new List<PresetEntry>();
        for (var k = 0; k < groups.Count; k++)
        {
            var g = groups[k];
            if (phasesNode is { Count: > 0 })
                phases.Add(new PresetPhase(Text(Get(g, "Name")) ?? "", Text(Get(g, "Boot")) == "SafeMode" ? "SafeMode" : "Normal"));
            foreach (var x in AsArray(Get(g, "Tweaks")))
            {
                if (x is JsonValue v && v.TryGetValue<string>(out var id)) entries.Add(new PresetEntry(id, null, false, k));
                else if (x is JsonObject o)
                    foreach (var (key, value) in o) entries.Add(new PresetEntry(key, ToValue(value), true, k));
            }
        }
        var name = Text(Get(j, "Name")) is { Length: > 0 } n ? n : System.IO.Path.GetFileNameWithoutExtension(path);
        return new Preset(name, Text(Get(j, "Description")) ?? "", entries, phases, path, isBuiltin);
    }

    // ConvertFrom-Json's property lookup ignores case
    private static JsonNode? Get(JsonObject? o, string key) =>
        o?.FirstOrDefault(p => string.Equals(p.Key, key, StringComparison.OrdinalIgnoreCase)).Value;

    private static IEnumerable<JsonNode?> AsArray(JsonNode? n) => n switch
    {
        JsonArray a => a,
        null => [],
        _ => [n],
    };

    private static string? Text(JsonNode? n) => n is JsonValue v ? (v.TryGetValue<string>(out var s) ? s : v.ToJsonString()) : null;

    /// <summary>A JSON value as ConvertFrom-Json gives it: text, a whole number (int, else long), a decimal, a bool, null.</summary>
    public static object? ToValue(JsonNode? n)
    {
        if (n is null) return null;
        if (n is JsonValue v)
        {
            var e = v.GetValue<JsonElement>();
            return e.ValueKind switch
            {
                JsonValueKind.String => e.GetString(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.Number when e.TryGetInt32(out var i) => i,
                JsonValueKind.Number when e.TryGetInt64(out var l) => l,
                JsonValueKind.Number => e.GetDecimal(),
                _ => null,
            };
        }
        if (n is JsonArray a) return a.Select(ToValue).ToArray();
        return n.ToJsonString();
    }

    /// <summary>The built-in presets (src/Presets), then the user's, each folder by file name.</summary>
    public IReadOnlyList<Preset> All()
    {
        var list = new List<Preset>();
        foreach (var path in builtin.List("src/Presets/").Where(p => p.EndsWith(".json", StringComparison.OrdinalIgnoreCase)).Order(StringComparer.OrdinalIgnoreCase))
            if (Read(builtin.ReadText(path), path, true) is { } p) list.Add(p);
        if (Directory.Exists(UserFolder))
            foreach (var path in Directory.GetFiles(UserFolder, "*.json").Order(StringComparer.OrdinalIgnoreCase))
                if (ReadFile(path) is { } p) list.Add(p);
        return list;
    }

    private Preset? ReadFile(string path)
    {
        try { return Read(File.ReadAllText(path), path, false); }
        catch (IOException e) { log.Write($"Warning: preset {path} could not be read ({e.Message})"); return null; }
    }

    /// <summary>A preset by name (built-in or the user's, ignoring case) or by .json file path, or null.</summary>
    public Preset? Find(string nameOrPath)
    {
        if (nameOrPath.EndsWith(".json", StringComparison.OrdinalIgnoreCase) && File.Exists(nameOrPath)) return ReadFile(Path.GetFullPath(nameOrPath));
        return All().FirstOrDefault(p => string.Equals(p.Name, nameOrPath, StringComparison.OrdinalIgnoreCase));
    }

    // ---- resolving

    /// <summary>
    /// A preset's Run items (Resolve-AkariPreset). Tweaks: every Tweak and Entry known ("group/*" = that Group's
    /// non-keep Entries among them). An Entry a wildcard and an id both name runs once. A Choice value equal to its
    /// Recommended one is left out (Apply sets it anyway). Revert: the reverse order, every item Revert, phase 0.
    /// </summary>
    public static Resolved Resolve(Preset preset, IReadOnlyList<Tweak> tweaks, bool revert = false)
    {
        var items = new List<PlanItem>();
        var unknown = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var byId = tweaks.GroupBy(t => t.Id, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
        foreach (var e in preset.Entries)
        {
            if (e.Id.EndsWith("/*", StringComparison.Ordinal))
            {
                var g = e.Id[..^2];
                foreach (var t in tweaks.Where(t => string.Equals(t.Group, g, StringComparison.OrdinalIgnoreCase) && !t.Keep))
                    if (seen.Add(t.Id)) items.Add(new PlanItem(t.Id, TweakMode.Apply, null, e.Phase));
                continue;
            }
            if (!byId.TryGetValue(e.Id, out var tw)) { unknown.Add(e.Id); continue; }
            if (!seen.Add(tw.Id)) continue;
            var item = new PlanItem(tw.Id, TweakMode.Apply, null, e.Phase);
            if (e.HasValue)
            {
                if (string.Equals(Data.PsSemantics.Text(e.Value), "Default", StringComparison.OrdinalIgnoreCase)) item = item with { Mode = TweakMode.Revert };
                else if (tw.Kind == TweakKind.Choice && !RegistryEngine.Matches(e.Value, tw.Recommended)) item = item with { Value = e.Value };
            }
            items.Add(item);
        }
        if (revert)
        {
            items.Reverse();
            items = items.Select(i => new PlanItem(i.Id, TweakMode.Revert)).ToList();
        }
        return new Resolved(items, unknown);
    }

    /// <summary>A preset's Run phases (Get-AkariPresetPhases): one per preset phase (empty ones too), else one Normal
    /// phase; Revert is always one phase. Items lose their phase index.</summary>
    public static IReadOnlyList<RunPhase> Phases(Preset preset, IReadOnlyList<PlanItem> items, bool revert = false)
    {
        if (revert || preset.Phases.Count == 0) return [new RunPhase(preset.Name, "Normal", items.Select(i => i with { Phase = 0 }).ToList())];
        return preset.Phases.Select((p, k) => new RunPhase(p.Name, p.Boot, items.Where(i => i.Phase == k).Select(i => i with { Phase = 0 }).ToList())).ToList();
    }

    // ---- saving

    /// <summary>The JSON entries for Run items: Apply = the id, a Choice value = { id: value }, Revert = { id: "Default" }.</summary>
    public static JsonArray Entries(IEnumerable<PlanItem> items)
    {
        var a = new JsonArray();
        foreach (var i in items)
        {
            if (i.Mode == TweakMode.Revert) a.Add(new JsonObject { [i.Id] = "Default" });
            else if (i.Value is not null) a.Add(new JsonObject { [i.Id] = ToNode(i.Value) });
            else a.Add(JsonValue.Create(i.Id));
        }
        return a;
    }

    private static JsonNode? ToNode(object? v) => v switch
    {
        null => null,
        string s => JsonValue.Create(s),
        bool b => JsonValue.Create(b),
        int n => JsonValue.Create(n),
        long n => JsonValue.Create(n),
        uint n => JsonValue.Create(n),
        ulong n => JsonValue.Create(n),
        double d => JsonValue.Create(d),
        decimal m => JsonValue.Create(m),
        JsonNode n => n.DeepClone(),
        _ => JsonValue.Create(Convert.ToString(v, CultureInfo.InvariantCulture)),
    };

    private static readonly JsonSerializerOptions Indented = new() { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>Writes a user preset (or Last used with a path) and returns its path (Save-AkariPreset). Extra: more
    /// top-level fields after Tweaks (an export's "Exported" block).</summary>
    public string Save(string name, IEnumerable<PlanItem> items, string description = "", string? path = null, JsonObject? extra = null)
    {
        if (string.IsNullOrEmpty(path))
        {
            var safe = Regex.Replace(name, @"[\\/:*?""<>|]", "_").Trim();
            if (safe.Length == 0) throw new ArgumentException("a preset needs a name");
            path = Path.Combine(UserFolder, safe + ".json");
        }
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var doc = new JsonObject { ["Name"] = name, ["Description"] = description, ["Tweaks"] = Entries(items) };
        if (extra != null) foreach (var (k, v) in extra) doc[k] = v?.DeepClone();
        File.WriteAllText(path, doc.ToJsonString(Indented), new UTF8Encoding(false));
        return path;
    }

    /// <summary>The last Guided Run's changes, or null when there is none yet.</summary>
    public Preset? LastUsed() => File.Exists(LastUsedPath) ? ReadFile(LastUsedPath) : null;

    public void SaveLastUsed(IEnumerable<PlanItem> items) => Save("Last used", items, "The changes of the last Guided Run", LastUsedPath);

    // ---- export (M5): this PC's settings as a preset

    /// <summary>The Tweaks an export reads: one-file Toggles and Choices this PC meets (no Entries, Apps, OneClick,
    /// Tools). The native app's exports leave out what it can't read yet.</summary>
    public static IReadOnlyList<Tweak> ExportTweaks(IEnumerable<Tweak> tweaks, ISystemInfo pc) =>
        tweaks.Where(t => t.Group is null && t.EntryKind is null && t.Kind is TweakKind.Toggle or TweakKind.Choice
            && t.Section is not ("Apps" or "OneClick" or "Tools") && Requirements.Check(t, pc) is null).ToList();

    /// <summary>One exportable Tweak as read on this PC (a Choice's current value, a Toggle's State).</summary>
    public sealed record ExportRow(Tweak Tweak, TweakState State, object? Value);

    /// <summary>
    /// Run items from what a PC has (ConvertTo-AkariExportItems): an Optimized Toggle = Apply; a Choice on its
    /// Recommended value = Apply, on another of its values (not the Default) = Apply with it. Pure.
    /// </summary>
    public static IReadOnlyList<PlanItem> ExportItems(IEnumerable<ExportRow> rows, Func<Tweak, object?> defaultFor)
    {
        var items = new List<PlanItem>();
        foreach (var r in rows)
        {
            var t = r.Tweak;
            if (t.Kind == TweakKind.Choice)
            {
                var v = r.Value;
                if (v is null || RegistryEngine.Matches(v, defaultFor(t))) continue;
                if (RegistryEngine.Matches(v, t.Recommended)) items.Add(new PlanItem(t.Id, TweakMode.Apply));
                else if (t.Editable || t.Choices.Any(c => RegistryEngine.Matches(v, c.Value))) items.Add(new PlanItem(t.Id, TweakMode.Apply, v));
            }
            else if (r.State == TweakState.Optimized) items.Add(new PlanItem(t.Id, TweakMode.Apply));
        }
        return items;
    }

    /// <summary>Reads every exportable Tweak's State here (seconds: in the background) -> Run items.</summary>
    public static IReadOnlyList<PlanItem> ExportItems(IEnumerable<Tweak> tweaks, States states, ISystemInfo pc) =>
        ExportItems(ExportTweaks(tweaks, pc).Select(t =>
        {
            object? v = null;
            if (t.Kind == TweakKind.Choice) { try { v = states.ChoiceValue(t); } catch (Exception) { } }
            return new ExportRow(t, t.Kind == TweakKind.Choice ? TweakState.Unknown : states.Of(t), v);
        }), states.DefaultFor);

    /// <summary>Writes this PC's settings to a file as a preset named after the PC, with an "Exported" block.</summary>
    public (string Path, int Count) Export(IEnumerable<Tweak> tweaks, States states, ISystemInfo pc, string path, string version, string computer, DateTime now)
    {
        var items = ExportItems(tweaks, states, pc);
        var date = now.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture);
        var extra = new JsonObject
        {
            ["Exported"] = new JsonObject { ["Computer"] = computer, ["Date"] = date, ["AkariVersion"] = version, ["WindowsBuild"] = pc.Build.ToString(CultureInfo.InvariantCulture) },
        };
        return (Save($"Exported from {computer}", items, $"Settings exported from {computer} on {date}", path, extra), items.Count);
    }
}
