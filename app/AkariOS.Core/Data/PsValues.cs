using System.Collections;

namespace AkariOS.Core.Data;

/// <summary>
/// A PowerShell hashtable as PsData reads it: keys case-insensitive (as in PowerShell), in the order written.
/// </summary>
public sealed class PsHashtable : IReadOnlyDictionary<string, object?>
{
    private readonly List<KeyValuePair<string, object?>> _items = [];
    private readonly Dictionary<string, object?> _map = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>A hashtable built in code (an Entry row from its name).</summary>
    public static PsHashtable Of(params (string Key, object? Value)[] items)
    {
        var h = new PsHashtable();
        foreach (var (k, v) in items) h.TryAdd(k, v);
        return h;
    }

    /// <summary>A copy with the key set (added, or replaced in place).</summary>
    public PsHashtable With(string key, object? value)
    {
        var h = new PsHashtable();
        foreach (var (k, v) in _items) h.TryAdd(k, string.Equals(k, key, StringComparison.OrdinalIgnoreCase) ? value : v);
        h.TryAdd(key, value);
        return h;
    }

    internal bool TryAdd(string key, object? value)
    {
        if (!_map.TryAdd(key, value)) return false;
        _items.Add(new(key, value));
        return true;
    }

    public object? this[string key] => _map[key];
    public IEnumerable<string> Keys => _items.Select(p => p.Key);
    public IEnumerable<object?> Values => _items.Select(p => p.Value);
    public int Count => _items.Count;
    public bool ContainsKey(string key) => _map.ContainsKey(key);
    public bool TryGetValue(string key, out object? value) => _map.TryGetValue(key, out value);
    public IEnumerator<KeyValuePair<string, object?>> GetEnumerator() => _items.GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    /// <summary>The value under the key, or null when it is missing.</summary>
    public object? Get(string key) => _map.TryGetValue(key, out var v) ? v : null;
}

/// <summary>A script block, kept as its text (between the braces): the native app never runs it.</summary>
public sealed record PsScriptBlock(string Text, int Line);

/// <summary>Any other expression (a command, an operator, an unknown variable), kept as its text.</summary>
public sealed record PsCode(string Text, int Line);

/// <summary><c>(Import-PowerShellDataFile "$PSScriptRoot\File").Key</c>: a data-list Group's rows.</summary>
public sealed record PsImport(string File, string Key, int Line);

/// <summary>A file read by PsData: its value (the hashtable it returns) and the variables assigned before it.</summary>
public sealed record PsFile(object? Value, IReadOnlyDictionary<string, object?> Variables, bool HasTopLevelCode)
{
    /// <summary>True when the file needs code to behave: a script block or another expression anywhere in it.</summary>
    public bool HasCode => HasTopLevelCode || PsData.HasCode(Value);
}

/// <summary>Shared data text that can't be read (PsData, RegReader), with its position (1-based).</summary>
public sealed class PsDataException(string message, int line, int column)
    : Exception($"line {line}, column {column}: {message}")
{
    public int Line { get; } = line;
    public int Column { get; } = column;

    /// <summary>Wrong even as code (a duplicate key, a value its cast can't hold): never read as PsCode instead.</summary>
    internal bool Fatal { get; init; }
}
