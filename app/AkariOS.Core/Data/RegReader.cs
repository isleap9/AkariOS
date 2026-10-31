using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace AkariOS.Core.Data;

/// <summary>One value line of a .reg file. Data: string (String, ExpandString), string[] (MultiString), uint (DWord),
/// ulong (QWord), byte[] (Binary, None and any other hex(n) type: <see cref="RawType"/> says which). Delete = "name"=-.
/// Raw: the bytes of a value written as hex, as written (null for "text" and dword:).</summary>
public sealed record RegFileValue(string Name, RegistryValueKind Kind, object? Data, bool Delete, int RawType, int Line)
{
    public byte[]? Raw { get; init; }
}

/// <summary>A [key] section (Path as written, HKEY_... ) with its values; Delete = [-key].</summary>
public sealed record RegFileKey(string Path, bool Delete, IReadOnlyList<RegFileValue> Values, int Line);

public sealed record RegFile(int Version, IReadOnlyList<RegFileKey> Keys);

/// <summary>
/// Reads .reg text (regedit's "Windows Registry Editor Version 5.00" and REGEDIT4, reg export's output): keys,
/// deleted keys, values of every type, deleted values, comments, lines continued with '\'. The PowerShell app's
/// readers are tests/RegFile.ps1 (OneClick\reg.reg) and ConvertFrom-AkariRegExport (a Store app's settings).
/// </summary>
public static partial class RegReader
{
    [GeneratedRegex(@"^\[(-?)\s*([^\]]+?)\s*\]\s*(;.*)?$")]
    private static partial Regex KeyLine();

    /// <summary>Decodes a .reg file's bytes: UTF-16 with its BOM (what regedit writes), else UTF-8.</summary>
    public static string Decode(byte[] bytes)
    {
        if (bytes.Length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) return Encoding.Unicode.GetString(bytes, 2, bytes.Length - 2);
        if (bytes.Length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) return Encoding.BigEndianUnicode.GetString(bytes, 2, bytes.Length - 2);
        if (bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) return Encoding.UTF8.GetString(bytes, 3, bytes.Length - 3);
        return Encoding.UTF8.GetString(bytes);
    }

    public static RegFile Parse(string text)
    {
        var lines = Logical(text);
        var i = 0;
        while (i < lines.Count && string.IsNullOrWhiteSpace(lines[i].Text)) i++;
        if (i == lines.Count) throw new PsDataException("an empty .reg file", 1, 1);
        var header = lines[i].Text.Trim().TrimStart('\uFEFF');
        var version = header switch
        {
            "Windows Registry Editor Version 5.00" => 5,
            "REGEDIT4" => 4,
            _ => throw new PsDataException($"not a .reg file: '{header}'", lines[i].Line, 1),
        };

        var keys = new List<RegFileKey>();
        string? path = null;
        var delete = false;
        var keyLine = 0;
        List<RegFileValue>? values = null;
        void Flush()
        {
            if (path != null) keys.Add(new RegFileKey(path, delete, values!, keyLine));
        }

        foreach (var (raw, line) in lines.Skip(i + 1))
        {
            var t = raw.Trim();
            if (t.Length == 0 || t[0] == ';') continue;
            if (t[0] == '[')
            {
                var m = KeyLine().Match(t);
                if (!m.Success) throw new PsDataException("a key line ends with ']'", line, 1);
                Flush();
                (path, delete, keyLine, values) = (m.Groups[2].Value, m.Groups[1].Value == "-", line, []);
                continue;
            }
            if (path == null) throw new PsDataException("a value before any [key]", line, 1);
            if (delete) throw new PsDataException("a value under a deleted [-key]", line, 1);
            values!.Add(ParseValue(t, line, version));
        }
        Flush();
        return new RegFile(version, keys);
    }

    /// <summary>A .reg key path as a Tweak row writes it: HKCU:\..., HKLM:\..., HKEY_CLASSES_ROOT as
    /// HKLM:\SOFTWARE\Classes\..., HKEY_USERS and the rest as Registry::HKEY_...\...</summary>
    public static string ToTweakPath(string regPath)
    {
        var slash = regPath.IndexOf('\\');
        var hive = (slash < 0 ? regPath : regPath[..slash]).ToUpperInvariant();
        var rest = slash < 0 ? "" : regPath[slash..];
        return hive switch
        {
            "HKEY_CURRENT_USER" or "HKCU" => "HKCU:" + rest,
            "HKEY_LOCAL_MACHINE" or "HKLM" => "HKLM:" + rest,
            "HKEY_CLASSES_ROOT" or "HKCR" => @"HKLM:\SOFTWARE\Classes" + rest,
            "HKEY_USERS" or "HKU" => @"Registry::HKEY_USERS" + rest,
            "HKEY_CURRENT_CONFIG" or "HKCC" => @"Registry::HKEY_CURRENT_CONFIG" + rest,
            _ => throw new ArgumentException($"unknown hive in '{regPath}'", nameof(regPath)),
        };
    }

    // ---- lines

    /// <summary>The file's lines with a trailing '\' joined to the next one (regedit wraps long hex values).</summary>
    private static List<(string Text, int Line)> Logical(string text)
    {
        var physical = text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        var result = new List<(string, int)>();
        for (var n = 0; n < physical.Length; n++)
        {
            var start = n + 1;
            var b = new StringBuilder(physical[n]);
            while (EndsContinued(b) && n + 1 < physical.Length)
            {
                b.Length = b.ToString().TrimEnd().Length - 1;
                b.Append(physical[++n].TrimStart());
            }
            result.Add((b.ToString(), start));
        }
        return result;
    }

    // a continuation only after hex data ("...,\"), never a string ending in an escaped backslash ("C:\\")
    private static bool EndsContinued(StringBuilder b)
    {
        var t = b.ToString().TrimEnd();
        return t.EndsWith('\\') && !t.TrimStart().StartsWith(';') && Regex.IsMatch(t, @"=\s*hex(\([0-9a-fA-F]+\))?:[0-9a-fA-F,\s]*\\$");
    }

    // ---- values

    private static RegFileValue ParseValue(string t, int line, int version)
    {
        string name;
        int at;
        if (t[0] == '@') { name = "(default)"; at = 1; }
        else if (t[0] == '"') { (name, at) = ReadQuoted(t, 0, line); }
        else throw new PsDataException("a value line starts with @ or \"", line, 1);
        while (at < t.Length && t[at] is ' ' or '\t') at++;
        if (at >= t.Length || t[at] != '=') throw new PsDataException("'=' expected", line, at + 1);
        var data = t[(at + 1)..].Trim();

        if (data == "-") return new RegFileValue(name, RegistryValueKind.Unknown, null, true, -1, line);
        if (data.StartsWith('"'))
        {
            var (s, end) = ReadQuoted(data, 0, line);
            if (data[end..].Trim().Length > 0 && !data[end..].TrimStart().StartsWith(';'))
                throw new PsDataException("text after the closing quote", line, at + 2 + end);
            return new RegFileValue(name, RegistryValueKind.String, s, false, 1, line);
        }
        var dw = Regex.Match(data, @"^dword:([0-9a-fA-F]{1,8})\s*(;.*)?$");
        if (dw.Success)
            return new RegFileValue(name, RegistryValueKind.DWord, uint.Parse(dw.Groups[1].Value, NumberStyles.HexNumber, CultureInfo.InvariantCulture), false, 4, line);
        var hx = Regex.Match(data, @"^hex(?:\(([0-9a-fA-F]+)\))?:\s*([0-9a-fA-F,\s]*?)\s*(;.*)?$");
        if (!hx.Success) throw new PsDataException($"unknown data '{data}'", line, at + 2);
        var type = hx.Groups[1].Success ? int.Parse(hx.Groups[1].Value, NumberStyles.HexNumber, CultureInfo.InvariantCulture) : 3;
        var bytes = Bytes(hx.Groups[2].Value, line);
        // REGEDIT4 writes text as ANSI bytes, version 5 as UTF-16
        string Text() => version == 4 ? Encoding.Latin1.GetString(bytes) : Encoding.Unicode.GetString(bytes);
        return HexValue() with { Raw = bytes };

        RegFileValue HexValue() => type switch
        {
            0 => new RegFileValue(name, RegistryValueKind.None, bytes, false, 0, line),
            1 => new RegFileValue(name, RegistryValueKind.String, Text().TrimEnd('\0'), false, 1, line),
            2 => new RegFileValue(name, RegistryValueKind.ExpandString, Text().TrimEnd('\0'), false, 2, line),
            3 => new RegFileValue(name, RegistryValueKind.Binary, bytes, false, 3, line),
            4 when bytes.Length == 4 => new RegFileValue(name, RegistryValueKind.DWord, BitConverter.ToUInt32(bytes), false, 4, line),
            7 => new RegFileValue(name, RegistryValueKind.MultiString, MultiString(Text()), false, 7, line),
            0xb when bytes.Length == 8 => new RegFileValue(name, RegistryValueKind.QWord, BitConverter.ToUInt64(bytes), false, 0xb, line),
            4 or 0xb => throw new PsDataException($"hex({type:x}) needs {(type == 4 ? 4 : 8)} bytes, not {bytes.Length}", line, at + 2),
            _ => new RegFileValue(name, RegistryValueKind.Unknown, bytes, false, type, line),
        };
    }

    private static string[] MultiString(string text)
    {
        var t = text.TrimEnd('\0');
        return t.Length == 0 ? [] : t.Split('\0');
    }

    private static byte[] Bytes(string hex, int line)
    {
        var parts = hex.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var b = new byte[parts.Length];
        for (var n = 0; n < parts.Length; n++)
            if (!byte.TryParse(parts[n], NumberStyles.HexNumber, CultureInfo.InvariantCulture, out b[n]))
                throw new PsDataException($"'{parts[n]}' is not a hex byte", line, 1);
        return b;
    }

    /// <summary>A "..." name or value from 'at' (the quote): \\ and \" unescaped. Returns it and the index after it.</summary>
    private static (string Text, int End) ReadQuoted(string t, int at, int line)
    {
        var b = new StringBuilder();
        for (var n = at + 1; n < t.Length; n++)
        {
            var c = t[n];
            if (c == '\\' && n + 1 < t.Length && t[n + 1] is '\\' or '"') { b.Append(t[++n]); continue; }
            if (c == '"') return (b.ToString(), n + 1);
            b.Append(c);
        }
        throw new PsDataException("this quote is never closed", line, at + 1);
    }
}
