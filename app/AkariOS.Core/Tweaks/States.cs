using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Tweaks;

/// <summary>What Akari last did to a Tweak with no other way to read it: true = Applied (state.json).</summary>
public interface IRememberedState
{
    bool? Get(string id);
    void Set(string id, bool applied);
}

/// <summary>
/// state.json, { "&lt;id&gt;": true|false } as the PowerShell app writes it (its own copy: the native app's lives in
/// %LOCALAPPDATA%\AkariOS.Native). Read on every call; a missing or broken file reads as empty.
/// </summary>
public sealed class JsonRememberedState(string path) : IRememberedState
{
    public string Path { get; } = path;

    private Dictionary<string, bool> Read()
    {
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(Path));
            return doc.RootElement.EnumerateObject()
                .Where(p => p.Value.ValueKind is JsonValueKind.True or JsonValueKind.False)
                .ToDictionary(p => p.Name, p => p.Value.GetBoolean(), StringComparer.OrdinalIgnoreCase);
        }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { return new(StringComparer.OrdinalIgnoreCase); }
    }

    public bool? Get(string id) => Read().TryGetValue(id, out var v) ? v : null;

    public void Set(string id, bool applied)
    {
        var s = Read();
        s[id] = applied;
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path)!);
        File.WriteAllText(Path, JsonSerializer.Serialize(s, new JsonSerializerOptions { WriteIndented = true }));
    }
}

/// <summary>
/// A Tweak's State (Get-AkariState), in its order: an Action has none (Unknown); Detect (its C#); a Choice's value
/// against Recommended and Default; Registry rows; what Akari last did. A Tweak the native app can't run (its C# is
/// missing) reads as Unknown.
/// </summary>
public sealed class States(TweakContext context, IRememberedState remembered)
{
    public TweakState Of(Tweak t)
    {
        if (t.Kind == TweakKind.Action) return TweakState.Unknown;
        if (t.Has("Detect"))
        {
            if (t.Code is null) return TweakState.Unknown;
            try { return t.Code.Detect(t, context); }
            catch (Exception) { return TweakState.Unknown; }
        }
        if (t.Kind == TweakKind.Choice)
        {
            object? current;
            try { current = ChoiceValue(t); }
            catch (Exception) { return TweakState.Unknown; }
            var def = DefaultFor(t);
            // a Value block's null: readable, but none of its values
            if (current is null && t.Has("Value")) return TweakState.Custom;
            if (current is null) return def is null ? TweakState.Default : TweakState.Unknown;
            if (RegistryEngine.Matches(current, t.Recommended)) return TweakState.Optimized;
            if (RegistryEngine.Matches(current, def)) return TweakState.Default;
            return TweakState.Custom;
        }
        if (t.RowsAreCode)
        {
            if (t.Code is null) return TweakState.Unknown;
            try { return context.Registry.State(t.Code.Rows(t, context), context.System.Build); }
            catch (Exception) { return TweakState.Unknown; }
        }
        if (t.Registry is { Count: > 0 }) return context.Registry.State(t.Registry, context.System.Build);
        return remembered.Get(t.Id) switch
        {
            true => TweakState.Optimized,
            false => TweakState.Default,
            null => TweakState.Unknown,
        };
    }

    /// <summary>A Choice's current value: its registry value, or its Value block's (C#). Throws when it can't be read.</summary>
    public object? ChoiceValue(Tweak t)
    {
        if (t.Kind != TweakKind.Choice) throw new InvalidOperationException($"{t.Id} is not a Choice");
        if (t.Has("Value"))
            return (t.Code ?? throw new NotSupportedException($"{t.Id} needs its C# to read its value")).ChoiceValue(t, context);
        var row = t.Registry is { Count: 1 } rows ? rows[0] : throw new InvalidOperationException($"{t.Id} has no registry row");
        return context.Registry.GetValue(row.Path, row.Name!);
    }

    /// <summary>A Tweak's Default for this machine: one value, or the Win10 / Win11 one of a per-OS map.</summary>
    public object? DefaultFor(Tweak t) =>
        t.Default is PsHashtable h && (h.ContainsKey("Win10") || h.ContainsKey("Win11"))
            ? new OsValue(h.Get("Win10"), h.Get("Win11")).For(context.System.Build)
            : t.Default;
}
