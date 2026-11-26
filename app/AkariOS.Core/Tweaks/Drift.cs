using System.Globalization;
using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Tweaks;

/// <summary>What a setting should be: the last Mode asked for, a Choice's value (null = its Recommended), when.</summary>
public sealed record Expected(TweakMode Mode, object? Value, string When);

/// <summary>A setting that went off what was last asked (Get-AkariDrift).</summary>
public sealed record DriftItem(string Id, string Name, TweakMode Mode, object? Value, TweakState State);

/// <summary>
/// expected.json (src/Core/State.ps1's Get- / Set-AkariExpected, plan 2026-11-26-new-features.md X3): <c>{ "id": {
/// "Mode": "Apply" | "Revert", "Value": …, "When": "…" } }</c>, the latest change per Toggle or Choice (no Group
/// Entries), written by the Runner on Applied, Reverted and Already. The PowerShell app's file has the same shape.
/// </summary>
public sealed class ExpectedStore(string path)
{
    public string Path { get; } = path;

    public Dictionary<string, Expected> All()
    {
        var s = new Dictionary<string, Expected>(StringComparer.OrdinalIgnoreCase);
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(Path));
            foreach (var p in doc.RootElement.EnumerateObject())
            {
                if (p.Value.ValueKind != JsonValueKind.Object || !p.Value.TryGetProperty("Mode", out var m)) continue;
                if (!Enum.TryParse<TweakMode>(m.GetString(), out var mode)) continue;
                var value = p.Value.TryGetProperty("Value", out var v) ? ValueOf(v) : null;
                var when = p.Value.TryGetProperty("When", out var w) && w.ValueKind == JsonValueKind.String ? w.GetString() ?? "" : "";
                s[p.Name] = new Expected(mode, value, when);
            }
        }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException or InvalidOperationException) { }
        return s;
    }

    private static object? ValueOf(JsonElement v) => v.ValueKind switch
    {
        JsonValueKind.Number when v.TryGetInt32(out var i) => i,
        JsonValueKind.Number when v.TryGetInt64(out var l) => l,
        JsonValueKind.Number => v.GetDouble(),
        JsonValueKind.String => v.GetString(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        _ => null,
    };

    /// <summary>Remove-AkariExpected: Undo put the user's own value back.</summary>
    public void Remove(string id)
    {
        var s = All();
        if (!s.Remove(id)) return;
        var o = s.OrderBy(p => p.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(p => p.Key, p => new Dictionary<string, object?> { ["Mode"] = p.Value.Mode.ToString(), ["Value"] = p.Value.Value, ["When"] = p.Value.When });
        File.WriteAllText(Path, JsonSerializer.Serialize(o, new JsonSerializerOptions { WriteIndented = true }));
    }

    /// <summary>Set-AkariExpected: Toggles and Choices only (not Group Entries); Value kept for a Choice's Apply.</summary>
    public void Set(Tweak t, TweakMode mode, object? value, DateTime now)
    {
        if (t.Kind is not (TweakKind.Toggle or TweakKind.Choice) || t.EntryKind is not null) return;
        var s = All();
        s[t.Id] = new Expected(mode, mode == TweakMode.Apply && t.Kind == TweakKind.Choice ? value : null, now.ToString("o", CultureInfo.InvariantCulture));
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path)!);
        var o = s.OrderBy(p => p.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(p => p.Key, p => new Dictionary<string, object?> { ["Mode"] = p.Value.Mode.ToString(), ["Value"] = p.Value.Value, ["When"] = p.Value.When });
        File.WriteAllText(Path, JsonSerializer.Serialize(o, new JsonSerializerOptions { WriteIndented = true }));
    }
}

/// <summary>The drift check (Get-AkariDrift): the settings in expected.json that are no longer what AkariOS set.</summary>
public static class Drift
{
    /// <summary>Test-AkariDrift (pure): Revert = its State isn't Default; Apply = not Optimized, or, for a Choice set to
    /// a value, its current value isn't that value. Unknown is never drift.</summary>
    public static bool IsDrift(TweakKind kind, TweakMode mode, object? value, TweakState state, object? current)
    {
        if (state == TweakState.Unknown) return false;
        if (mode == TweakMode.Revert) return state != TweakState.Default;
        if (kind == TweakKind.Choice && value is not null) return !(current is not null && RegistryEngine.Matches(current, value));
        return state != TweakState.Optimized;
    }

    /// <summary>Get-AkariDrift: by name; Tweaks no longer loaded, Actions, Entries and ones this PC doesn't meet left out.</summary>
    public static IReadOnlyList<DriftItem> Find(IEnumerable<Tweak> tweaks, IReadOnlyDictionary<string, Expected> expected, States states, ISystemInfo pc)
    {
        var byId = tweaks.Where(t => t.Kind is TweakKind.Toggle or TweakKind.Choice && t.EntryKind is null)
            .GroupBy(t => t.Id, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
        var list = new List<DriftItem>();
        foreach (var (id, e) in expected)
        {
            if (!byId.TryGetValue(id, out var t) || Requirements.Check(t, pc) is not null) continue;
            TweakState state;
            try { state = states.Of(t); } catch (Exception) { state = TweakState.Unknown; }
            object? current = null;
            if (t.Kind == TweakKind.Choice && e.Mode == TweakMode.Apply && e.Value is not null)
            {
                try { current = states.ChoiceValue(t); } catch (Exception) { current = null; }
            }
            if (IsDrift(t.Kind, e.Mode, e.Value, state, current)) list.Add(new DriftItem(t.Id, t.Name, e.Mode, e.Value, state));
        }
        var byName = StringComparer.Create(CultureInfo.CurrentCulture, ignoreCase: true);
        return list.OrderBy(d => d.Name, byName).ToList();
    }

    /// <summary>ConvertTo-AkariDriftPreset: Apply = the id (a Choice with a value: id = value), Revert = id = Default.</summary>
    public static Preset ToPreset(IEnumerable<DriftItem> drift) => new("Settings that went back", "AkariOS settings Windows changed back",
        drift.Select(d => d.Mode == TweakMode.Revert ? new PresetEntry(d.Id, "Default", true, 0)
            : d.Value is not null ? new PresetEntry(d.Id, d.Value, true, 0) : new PresetEntry(d.Id, null, false, 0)).ToList(),
        [], "", false);
}
