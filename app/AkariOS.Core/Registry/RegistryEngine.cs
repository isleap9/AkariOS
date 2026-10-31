using System.Globalization;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.Core.Registry;

/// <summary>
/// Registry rows (src/Core/Registry.ps1): read, write, delete, Apply / Revert and State, through Microsoft.Win32.Registry
/// (the 64-bit view). Paths are literal ('HKLM:\SOFTWARE\Classes\*' is the all-files key); '(default)' is a key's
/// unnamed value; a missing key or value reads as null; a DWord reads back unsigned, a QWord as ulong, an ExpandString
/// expanded. Where a path is comes from <see cref="IRegistryPaths"/> (HKCU = the real user; tests: a test key).
/// </summary>
public sealed class RegistryEngine(IRegistryPaths paths, ITrustedInstaller? trusted = null)
{
    public IRegistryPaths Paths { get; } = paths;

    private static RegistryKey Base(RegistryHive hive) => RegistryKey.OpenBaseKey(hive, RegistryView.Registry64);

    private static string ValueName(string name) => name == "(default)" ? "" : name;

    private T Use<T>(string path, bool write, Func<RegistryKey?, T> act)
    {
        var p = Paths.Resolve(path);
        using var b = Base(p.Hive);
        if (p.Sub.Length == 0) return act(b);
        using var k = write ? b.CreateSubKey(p.Sub, writable: true) : b.OpenSubKey(p.Sub);
        return act(k);
    }

    // ---- reads

    /// <summary>The value, or null when the key or value is missing (Get-AkariRegValue).</summary>
    public object? GetValue(string path, string name) => Use(path, write: false, k => k?.GetValue(ValueName(name)) switch
    {
        int n => unchecked((uint)n),
        long l => unchecked((ulong)l),
        var v => v,
    });

    /// <summary>The value's kind, or null when it is missing.</summary>
    public RegistryValueKind? GetKind(string path, string name) => Use(path, write: false, k =>
        k != null && k.GetValueNames().Contains(ValueName(name), StringComparer.OrdinalIgnoreCase) ? k.GetValueKind(ValueName(name)) : (RegistryValueKind?)null);

    public bool KeyExists(string path) => Use(path, write: false, k => k != null);

    // ---- writes

    /// <summary>Writes a value (Set-Reg), creating the key. Type: DWord, QWord, String, ExpandString, MultiString,
    /// Binary (a byte[], a list of numbers, or 'ab,01' hex text).</summary>
    public void SetValue(string path, string name, object? value, string type)
    {
        var kind = KindOf(type);
        var data = Convert(value, kind, $@"{path}\{name}");
        Use<object?>(path, write: true, k => { k!.SetValue(ValueName(name), data, kind); return null; });
    }

    /// <summary>Deletes a value (Remove-Reg); a missing key or value is fine.</summary>
    public void RemoveValue(string path, string name)
    {
        var p = Paths.Resolve(path);
        using var b = Base(p.Hive);
        using var k = p.Sub.Length == 0 ? null : b.OpenSubKey(p.Sub, writable: true);
        (p.Sub.Length == 0 ? b : k)?.DeleteValue(ValueName(name), throwOnMissingValue: false);
    }

    public void CreateKey(string path) => Use<object?>(path, write: true, _ => null);

    /// <summary>Deletes a key with everything in it; a missing key is fine.</summary>
    public void DeleteKey(string path)
    {
        // the row's own path, not where it resolves: 'HKCU:' is HKEY_USERS\<sid>, the user's whole hive
        var p = Paths.Resolve(path);
        if (RegPath.Split(path).Sub.Length == 0 || p.Sub.Length == 0) throw new InvalidOperationException($"refusing to delete a whole hive ({path})");
        using var b = Base(p.Hive);
        b.DeleteSubKeyTree(p.Sub, throwOnMissingSubKey: false);
    }

    // ---- rows

    /// <summary>
    /// Apply = each row's Value, Revert = its Default for this build (null = delete). A key row creates the key ('Key')
    /// or deletes it with its contents (null). Trusted: the HKLM rows are written as TrustedInstaller
    /// (Invoke-AkariRegistryTrusted), the rest as Akari.
    /// </summary>
    public void Invoke(IEnumerable<RegistryRow> rows, TweakMode mode, int build, bool asTrusted = false)
    {
        var list = rows.ToList();
        if (!asTrusted) { foreach (var r in list) Write(r, mode, build); return; }
        if (trusted is null) throw new InvalidOperationException("no TrustedInstaller runner given");
        var machine = list.Where(r => RegPath.Split(r.Path).Hive == "HKLM").ToList();
        foreach (var r in list.Except(machine)) Write(r, mode, build);
        if (machine.Count > 0) trusted.Run(() => { foreach (var r in machine) Write(r, mode, build); });
    }

    private void Write(RegistryRow r, TweakMode mode, int build)
    {
        var v = mode == TweakMode.Apply ? r.Value : r.Default.For(build);
        if (r.IsKeyRow)
        {
            if (v is null) DeleteKey(r.Path);
            else CreateKey(r.Path);
        }
        else if (v is null) RemoveValue(r.Path, r.Name!);
        else SetValue(r.Path, r.Name!, v, r.Type ?? "DWord");
    }

    /// <summary>
    /// Optimized when every row reads as its Value, Default when every row reads as its Default, else Custom;
    /// Unknown when a row can't be read (Get-AkariRegistryState).
    /// </summary>
    public TweakState State(IEnumerable<RegistryRow> rows, int build)
    {
        try
        {
            bool optimized = true, isDefault = true;
            foreach (var r in rows)
            {
                var current = r.IsKeyRow ? (KeyExists(r.Path) ? "Key" : null) : GetValue(r.Path, r.Name!);
                if (!Matches(current, Expected(r, r.Value))) optimized = false;
                if (!Matches(current, Expected(r, r.Default.For(build)))) isDefault = false;
            }
            return optimized ? TweakState.Optimized : isDefault ? TweakState.Default : TweakState.Custom;
        }
        catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException or ArgumentException)
        {
            return TweakState.Unknown;
        }
    }

    // an ExpandString reads back expanded (%windir% -> C:\Windows): compare with the expected text expanded too
    private static object? Expected(RegistryRow r, object? v) =>
        string.Equals(r.Type, "ExpandString", StringComparison.OrdinalIgnoreCase) && v is string s ? Environment.ExpandEnvironmentVariables(s) : v;

    /// <summary>
    /// Test-AkariRegMatch: null expected = the value must be absent; otherwise both as text, item by item joined
    /// with ',' (a byte array, a list), a negative int compared unsigned (a DWord written as a hex literal).
    /// </summary>
    public static bool Matches(object? current, object? expected)
    {
        if (expected is null) return current is null;
        if (current is null) return false;
        return string.Equals(MatchText(current), MatchText(expected), StringComparison.OrdinalIgnoreCase);
    }

    private static string MatchText(object v)
    {
        static string One(object? x) => x switch
        {
            null => "",
            int n when n < 0 => unchecked((uint)n).ToString(CultureInfo.InvariantCulture),
            // a QWord reads back as ulong here (PowerShell reads a long): a negative long compares as its 64 bits
            long l when l < 0 => unchecked((ulong)l).ToString(CultureInfo.InvariantCulture),
            _ => PsSemantics.Text(x) ?? "",
        };
        return v switch
        {
            string s => s,
            byte[] b => string.Join(',', b.Select(x => x.ToString(CultureInfo.InvariantCulture))),
            string[] a => string.Join(',', a),
            object?[] a => string.Join(',', a.Select(One)),
            _ => One(v),
        };
    }

    // ---- values

    public static RegistryValueKind KindOf(string type) => type.ToLowerInvariant() switch
    {
        "dword" => RegistryValueKind.DWord,
        "qword" => RegistryValueKind.QWord,
        "string" => RegistryValueKind.String,
        "expandstring" => RegistryValueKind.ExpandString,
        "multistring" => RegistryValueKind.MultiString,
        "binary" => RegistryValueKind.Binary,
        _ => throw new ArgumentException($"unknown registry type '{type}'"),
    };

    /// <summary>A row's value as the registry API takes it for the kind.</summary>
    public static object Convert(object? value, RegistryValueKind kind, string what)
    {
        try
        {
            return kind switch
            {
                // the registry API wants a signed int for DWords above 2^31 (as Set-Reg does)
                RegistryValueKind.DWord => unchecked((int)ToUInt64(value)),
                RegistryValueKind.QWord => unchecked((long)ToUInt64(value)),
                RegistryValueKind.String or RegistryValueKind.ExpandString => PsSemantics.Text(value) ?? "",
                RegistryValueKind.MultiString => value switch
                {
                    string[] a => a,
                    object?[] a => a.Select(x => PsSemantics.Text(x) ?? "").ToArray(),
                    _ => [PsSemantics.Text(value) ?? ""],
                },
                RegistryValueKind.Binary => value switch
                {
                    byte[] b => b,
                    string hex => hex.Length == 0 ? [] : hex.Split(',').Select(h => byte.Parse(h.Trim(), NumberStyles.HexNumber, CultureInfo.InvariantCulture)).ToArray(),
                    object?[] a => a.Select(x => System.Convert.ToByte(x, CultureInfo.InvariantCulture)).ToArray(),
                    _ => throw new ArgumentException("not bytes"),
                },
                _ => throw new ArgumentException($"can't write {kind}"),
            };
        }
        catch (Exception e) when (e is FormatException or OverflowException or InvalidCastException or ArgumentException)
        {
            throw new ArgumentException($"{what}: '{PsSemantics.Text(value)}' can't be written as {kind}", e);
        }
    }

    // a number as its 64 bits: a negative int (a DWord written as a hex literal) keeps its 32 bits
    private static ulong ToUInt64(object? v) => v switch
    {
        int n => unchecked((uint)n),
        long l => unchecked((ulong)l),
        uint u => u,
        ulong u => u,
        bool b => b ? 1u : 0u,
        string s when s.StartsWith("0x", StringComparison.OrdinalIgnoreCase) => ulong.Parse(s[2..], NumberStyles.HexNumber, CultureInfo.InvariantCulture),
        _ => System.Convert.ToUInt64(v, CultureInfo.InvariantCulture),
    };
}
