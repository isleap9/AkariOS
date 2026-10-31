using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace AkariOS.Core.Data;

/// <summary>
/// Reads the PowerShell data the PowerShell app's Tweak files and .psd1 lists are written in, without PowerShell
/// (ADR 0007): <c>@{}</c> and <c>@()</c>, comma lists, strings, numbers (hex as PowerShell 5.1 reads it: up to
/// 0xFFFFFFFF an int, so 0xFFFFFFFF = -1), <c>$true</c> / <c>$false</c> / <c>$null</c>, the casts <c>[byte[]]</c>,
/// <c>[uint64]</c>, <c>[int]</c>, <c>[long]</c>, <c>[uint32]</c>, comments, here-strings, top-level
/// <c>$name = value</c> assignments used later (<c>$k</c>, <c>"$k\command"</c>), and
/// <c>(Import-PowerShellDataFile "$PSScriptRoot\File").Key</c>. A script block becomes a <see cref="PsScriptBlock"/>,
/// any other expression a <see cref="PsCode"/>: the file still gives its data, and C# gives the behaviour.
/// Text it can't read at all (an unclosed string or bracket, a duplicate key) throws a <see cref="PsDataException"/>.
/// </summary>
public static partial class PsData
{
    public static PsFile Parse(string text) => new Parser(text).ParseFile();

    /// <summary>The file's value alone (tests, one-off reads).</summary>
    public static object? ParseValue(string text) => Parse(text).Value;

    /// <summary>True when a script block or another expression is anywhere in the value.</summary>
    public static bool HasCode(object? value) => value switch
    {
        PsScriptBlock or PsCode => true,
        PsHashtable h => h.Values.Any(HasCode),
        object?[] a => a.Any(HasCode),
        _ => false,
    };

    [GeneratedRegex(@"\G\(\s*Import-PowerShellDataFile\s+""\$PSScriptRoot\\([^""$`]+)""\s*\)\.([A-Za-z_]\w*)", RegexOptions.IgnoreCase)]
    private static partial Regex ImportForm();

    [GeneratedRegex(@"\G(?:0[xX](?<hex>[0-9a-fA-F]+)|(?<dec>\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?))(?<l>[lL])?(?![\w.])")]
    private static partial Regex NumberForm();

    private sealed class Parser(string s)
    {
        private int _i;
        private readonly Dictionary<string, object?> _vars = new(StringComparer.OrdinalIgnoreCase);
        private bool _topCode;

        // ---- the file: assignments, then the one value it returns

        public PsFile ParseFile()
        {
            if (s.Length > 0 && s[0] == '﻿') _i = 1;
            object? result = null;
            var found = false;
            while (true)
            {
                SkipSpace(newlines: true);
                if (End) break;
                if (TryAssignment()) continue;
                var start = _i;
                var v = ParseStatement();
                if (v is PsCode && Peek(start) != '@' && Peek(start) != '(')
                {
                    // a command at the top (dot-sourcing, a call): not the file's value
                    _topCode = true;
                    continue;
                }
                if (found) throw Error("the file returns more than one value", start);
                (result, found) = (v, true);
            }
            if (!found) throw Error("the file returns no value", _i);
            return new PsFile(result, new Dictionary<string, object?>(_vars, StringComparer.OrdinalIgnoreCase), _topCode);
        }

        private bool TryAssignment()
        {
            var m = Regex.Match(s[_i..Math.Min(s.Length, _i + 200)], @"^\$([A-Za-z_]\w*)[ \t]*=(?![=])");
            if (!m.Success) return false;
            _i += m.Length;
            SkipSpace(newlines: true);
            _vars[m.Groups[1].Value] = ParseStatement();
            return true;
        }

        // ---- statements and values

        /// <summary>A value up to the end of its statement; anything that isn't data becomes PsCode.</summary>
        private object? ParseStatement()
        {
            var start = _i;
            try
            {
                if (TryCommaList(out var v))
                {
                    SkipSpace(newlines: false);
                    if (AtStatementEnd) return v;
                }
            }
            catch (PsDataException e) when (!e.Fatal)
            {
                // not data (e.g. @{ $x = 1 }): read as code below, which still fails on an unclosed string or bracket
            }
            _i = start;
            return CaptureCode(start);
        }

        private bool TryCommaList(out object? value)
        {
            value = null;
            if (!TryPrimary(out var first)) return false;
            SkipSpace(newlines: false);
            if (Peek() != ',') { value = first; return true; }
            var list = new List<object?> { first };
            while (Peek() == ',')
            {
                _i++;
                SkipSpace(newlines: true);
                if (!TryPrimary(out var next)) return false;
                list.Add(next);
                SkipSpace(newlines: false);
            }
            value = list.ToArray();
            return true;
        }

        private bool TryPrimary(out object? value)
        {
            value = null;
            if (End) return false;
            var c = s[_i];
            var start = _i;
            bool ok;
            switch (c)
            {
                case '@' when Peek(_i + 1) == '{': value = ParseHashtable(); ok = true; break;
                case '@' when Peek(_i + 1) == '(': value = ParseArray(); ok = true; break;
                case '@' when Peek(_i + 1) is '\'' or '"': ok = TryHereString(out value); break;
                case '(':
                    var im = ImportForm().Match(s, _i);
                    if (im.Success)
                    {
                        value = new PsImport(im.Groups[1].Value, im.Groups[2].Value, LineAt(_i));
                        _i += im.Length;
                        return true;
                    }
                    ok = TryParen(out value);
                    break;
                case '{': value = new PsScriptBlock(CaptureBlock(), LineAt(start)); ok = true; break;
                case '\'': value = ReadSingleQuoted(); ok = true; break;
                case '"': ok = TryDoubleQuoted(out value); break;
                case '[': ok = TryCast(out value); break;
                case '$': ok = TryVariable(out value); break;
                case '-' when Peek(_i + 1) is >= '0' and <= '9' or '.':
                    _i++;
                    ok = TryNumber(out value);
                    if (ok) value = Negate(value, start);
                    break;
                case >= '0' and <= '9' or '.': ok = TryNumber(out value); break;
                default: ok = false; break;
            }
            // a member, an index or a call right after it (".Count", "[0]") is code
            if (ok && !End && s[_i] is '.' or '[' && !(s[_i] == '.' && Peek(_i + 1) is '.')) ok = false;
            return ok;
        }

        private PsHashtable ParseHashtable()
        {
            var open = _i;
            _i += 2;
            var h = new PsHashtable();
            while (true)
            {
                SkipSpace(newlines: true, semicolons: true);
                if (End) throw Error("this @{ is never closed", open);
                if (s[_i] == '}') { _i++; return h; }
                var keyAt = _i;
                var key = ReadKey();
                SkipSpace(newlines: false);
                if (Peek() != '=') throw Error($"'=' expected after the key '{key}'", _i);
                _i++;
                SkipSpace(newlines: true);
                var value = ParseStatement();
                if (!h.TryAdd(key, value)) throw Error($"duplicate key '{key}'", keyAt, fatal: true);
            }
        }

        private string ReadKey()
        {
            var c = Peek();
            if (c == '\'') return ReadSingleQuoted();
            if (c == '"')
            {
                if (TryDoubleQuoted(out var v) && v is string k) return k;
                throw Error("a key with a variable in it", _i);
            }
            var m = Regex.Match(s[_i..Math.Min(s.Length, _i + 200)], @"^[A-Za-z0-9_][\w.\-]*");
            if (!m.Success) throw Error("a key expected", _i);
            _i += m.Length;
            return m.Value;
        }

        private object?[] ParseArray()
        {
            var open = _i;
            _i += 2;
            var list = new List<object?>();
            while (true)
            {
                SkipSpace(newlines: true, semicolons: true);
                if (End) throw Error("this @( is never closed", open);
                if (s[_i] == ')') { _i++; return list.ToArray(); }
                var v = ParseStatement();
                // @() collects what each statement outputs: a comma list's items, one by one
                if (v is object?[] items) list.AddRange(items);
                else list.Add(v);
            }
        }

        private bool TryParen(out object? value)
        {
            var open = _i;
            _i++;
            SkipSpace(newlines: true);
            value = ParseStatement();
            SkipSpace(newlines: true);
            if (Peek() != ')')
            {
                _i = open;
                return false;
            }
            _i++;
            if (value is PsCode) { _i = open; return false; }
            return true;
        }

        private bool TryCast(out object? value)
        {
            value = null;
            var m = Regex.Match(s[_i..Math.Min(s.Length, _i + 40)], @"^\[\s*([A-Za-z][\w.]*)\s*(\[\])?\s*\]");
            if (!m.Success) return false;
            var type = m.Groups[1].Value.ToLowerInvariant().Replace("system.", "") + m.Groups[2].Value;
            var at = _i;
            _i += m.Length;
            SkipSpace(newlines: false);
            if (!TryPrimary(out var inner) || inner is PsCode or PsScriptBlock) return false;
            value = Cast(type, inner, at);
            return value is not PsCode;
        }

        private object? Cast(string type, object? v, int at)
        {
            try
            {
                return type switch
                {
                    "byte[]" => v switch
                    {
                        object?[] a => a.Select(x => Convert.ToByte(x, CultureInfo.InvariantCulture)).ToArray(),
                        byte[] b => b,
                        _ => new[] { Convert.ToByte(v, CultureInfo.InvariantCulture) },
                    },
                    "uint64" or "ulong" => Convert.ToUInt64(v, CultureInfo.InvariantCulture),
                    "int" or "int32" => Convert.ToInt32(v, CultureInfo.InvariantCulture),
                    "long" or "int64" => Convert.ToInt64(v, CultureInfo.InvariantCulture),
                    "uint32" or "uint" => Convert.ToUInt32(v, CultureInfo.InvariantCulture),
                    "string" => Convert.ToString(v, CultureInfo.InvariantCulture),
                    _ => new PsCode(s[at.._i], LineAt(at)),
                };
            }
            catch (Exception e) when (e is OverflowException or FormatException or InvalidCastException)
            {
                throw Error($"[{type}] can't hold {v}", at, fatal: true);
            }
        }

        private bool TryVariable(out object? value)
        {
            value = null;
            var m = Regex.Match(s[_i..Math.Min(s.Length, _i + 200)], @"^\$([A-Za-z_]\w*)(?![:\w])");
            if (!m.Success) return false;
            var name = m.Groups[1].Value;
            switch (name.ToLowerInvariant())
            {
                case "true": value = true; break;
                case "false": value = false; break;
                case "null": value = null; break;
                default:
                    if (!_vars.TryGetValue(name, out value) || value is PsCode or PsScriptBlock) return false;
                    break;
            }
            _i += m.Length;
            return true;
        }

        private bool TryNumber(out object? value)
        {
            value = null;
            var m = NumberForm().Match(s, _i);
            if (!m.Success) return false;
            var at = _i;
            _i += m.Length;
            var isLong = m.Groups["l"].Success;
            if (m.Groups["hex"].Success)
            {
                if (!ulong.TryParse(m.Groups["hex"].Value, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var u))
                    throw Error("the hex number is too big", at, fatal: true);
                // PowerShell 5.1: up to 32 bits an int (0xFFFFFFFF = -1), else a long (both read as two's complement)
                value = !isLong && u <= uint.MaxValue ? (object)unchecked((int)(uint)u) : unchecked((long)u);
                return true;
            }
            var text = m.Groups["dec"].Value;
            if (!text.Contains('.') && !text.Contains('e') && !text.Contains('E'))
            {
                if (!isLong && int.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out var n)) value = n;
                else if (long.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out var l)) value = l;
                else value = decimal.Parse(text, NumberStyles.None, CultureInfo.InvariantCulture);
                return true;
            }
            value = double.Parse(text, NumberStyles.Float, CultureInfo.InvariantCulture);
            return true;
        }

        private object? Negate(object? v, int at) => v switch
        {
            int n => n == int.MinValue ? (object)-(long)n : -n,
            long l => -l,
            double d => -d,
            decimal m => -m,
            _ => throw Error("a number expected after '-'", at),
        };

        // ---- strings

        private string ReadSingleQuoted()
        {
            var open = _i;
            _i++;
            var b = new StringBuilder();
            while (true)
            {
                if (End) throw Error("this string is never closed", open);
                var c = s[_i++];
                if (IsSingleQuote(c))
                {
                    if (!End && IsSingleQuote(s[_i])) { b.Append(c); _i++; continue; }
                    return b.ToString();
                }
                b.Append(c);
            }
        }

        /// <summary>A "..." string; a variable PsData knows is put in, any other ($env:, $(...)) makes it PsCode.</summary>
        private bool TryDoubleQuoted(out object? value)
        {
            var open = _i;
            _i++;
            var b = new StringBuilder();
            var code = false;
            while (true)
            {
                if (End) throw Error("this string is never closed", open);
                var c = s[_i++];
                if (IsDoubleQuote(c))
                {
                    if (!End && IsDoubleQuote(s[_i])) { b.Append(c); _i++; continue; }
                    break;
                }
                if (c == '`')
                {
                    if (End) throw Error("this string is never closed", open);
                    b.Append(Escape(s[_i++]));
                    continue;
                }
                if (c == '$' && !End)
                {
                    var n = s[_i];
                    if (n == '(') { SkipBalanced(_i, '(', ')'); code = true; continue; }
                    if (n == '{')
                    {
                        var close = s.IndexOf('}', _i);
                        if (close < 0) throw Error("this ${ is never closed", _i);
                        code |= !Expand(s[(_i + 1)..close], b);
                        _i = close + 1;
                        continue;
                    }
                    var m = Regex.Match(s[_i..Math.Min(s.Length, _i + 200)], @"^(?:(\w+):)?([A-Za-z_]\w*)");
                    if (m.Success && (n is '_' || char.IsLetter(n)))
                    {
                        _i += m.Length;
                        // $env:X and other scopes: read when it runs, not here
                        code |= m.Groups[1].Success || !Expand(m.Groups[2].Value, b);
                        continue;
                    }
                }
                b.Append(c);
            }
            value = code ? new PsCode(s[open.._i], LineAt(open)) : b.ToString();
            return true;
        }

        private bool Expand(string name, StringBuilder b)
        {
            if (!_vars.TryGetValue(name, out var v) || v is PsCode or PsScriptBlock or PsHashtable or object?[] or byte[])
                return false;
            b.Append(v switch
            {
                null => "",
                bool x => x ? "True" : "False",
                IFormattable f => f.ToString(null, CultureInfo.InvariantCulture),
                _ => v.ToString(),
            });
            return true;
        }

        private static char Escape(char c) => c switch
        {
            '0' => '\0', 'a' => '\a', 'b' => '\b', 'f' => '\f', 'n' => '\n', 'r' => '\r', 't' => '\t', 'v' => '\v',
            _ => c,
        };

        private bool TryHereString(out object? value)
        {
            var open = _i;
            var single = s[_i + 1] == '\'';
            var quote = single ? '\'' : '"';
            _i += 2;
            while (!End && s[_i] is ' ' or '\t') _i++;
            if (End || s[_i] is not ('\r' or '\n')) throw Error("a here-string starts with a new line", open);
            if (s[_i] == '\r') _i++;
            if (!End && s[_i] == '\n') _i++;
            var bodyStart = _i;
            var end = Regex.Match(s[bodyStart..], $@"(?m)\r?\n{Regex.Escape(quote.ToString())}@");
            var empty = s.Length > bodyStart + 1 && s[bodyStart] == quote && s[bodyStart + 1] == '@';
            if (!end.Success && !empty) throw Error("this here-string is never closed", open);
            var body = empty ? "" : s.Substring(bodyStart, end.Index);
            _i = empty ? bodyStart + 2 : bodyStart + end.Index + end.Length;
            if (single || !body.Contains('$') && !body.Contains('`'))
            {
                value = body;
                return true;
            }
            value = new PsCode(s[open.._i], LineAt(open));
            return true;
        }

        private static bool IsSingleQuote(char c) => c is '\'' or '‘' or '’' or '‚' or '‛';
        private static bool IsDoubleQuote(char c) => c is '"' or '“' or '”' or '„';

        // ---- code kept as text

        /// <summary>The text of a script block, between its braces (the braces skipped).</summary>
        private string CaptureBlock()
        {
            var open = _i;
            SkipBalanced(_i, '{', '}');
            return s[(open + 1)..(_i - 1)];
        }

        /// <summary>From start to the end of the statement (a new line, ';', or the closing bracket around it).</summary>
        private PsCode CaptureCode(int start)
        {
            _i = start;
            while (!End)
            {
                var c = s[_i];
                if (c is '\n' or ';' or ')' or '}') break;
                if (c == '\r' && Peek(_i + 1) == '\n') break;
                if (SkipNonCode()) continue;
                switch (c)
                {
                    case '{': SkipBalanced(_i, '{', '}'); continue;
                    case '(': SkipBalanced(_i, '(', ')'); continue;
                    case '[': SkipBalanced(_i, '[', ']'); continue;
                    case '`' when Peek(_i + 1) is '\r' or '\n':
                        _i++;
                        if (Peek() == '\r') _i++;
                        if (Peek() == '\n') _i++;
                        continue;
                    case '|' or ',':
                        _i++;
                        SkipSpace(newlines: true);
                        continue;
                }
                _i++;
            }
            var end = _i;
            while (end > start && char.IsWhiteSpace(s[end - 1])) end--;
            if (end == start) throw Error("a value expected", start);
            return new PsCode(s[start..end], LineAt(start));
        }

        /// <summary>Moves past the bracket opened at 'at' and everything in it (strings, comments, nested brackets).</summary>
        private void SkipBalanced(int at, char open, char close)
        {
            _i = at + 1;
            while (true)
            {
                if (End) throw Error($"this {open} is never closed", at);
                var c = s[_i];
                if (c == close) { _i++; return; }
                if (SkipNonCode()) continue;
                switch (c)
                {
                    case '{': SkipBalanced(_i, '{', '}'); continue;
                    case '(': SkipBalanced(_i, '(', ')'); continue;
                    case '[': SkipBalanced(_i, '[', ']'); continue;
                    case '}' or ')' or ']': throw Error($"'{c}' doesn't close the {open} opened before it", _i);
                    case '`': _i += 2; continue;
                }
                _i++;
            }
        }

        /// <summary>Skips a string, here-string or comment at the cursor (inside code); false when there is none.</summary>
        private bool SkipNonCode()
        {
            var c = s[_i];
            if (c == '@' && Peek(_i + 1) is '\'' or '"' && IsHereStart(_i))
            {
                TryHereString(out _);
                return true;
            }
            if (IsSingleQuote(c)) { ReadSingleQuoted(); return true; }
            if (IsDoubleQuote(c)) { SkipDoubleQuotedCode(); return true; }
            if (c == '<' && Peek(_i + 1) == '#') { SkipBlockComment(); return true; }
            if (c == '#' && (_i == 0 || char.IsWhiteSpace(s[_i - 1]) || s[_i - 1] is ';' or '{' or '(' or '}' or ')'))
            {
                while (!End && s[_i] is not ('\r' or '\n')) _i++;
                return true;
            }
            return false;
        }

        private bool IsHereStart(int at)
        {
            var j = at + 2;
            while (j < s.Length && s[j] is ' ' or '\t') j++;
            return j >= s.Length || s[j] is '\r' or '\n';
        }

        private void SkipDoubleQuotedCode()
        {
            var open = _i;
            _i++;
            while (true)
            {
                if (End) throw Error("this string is never closed", open);
                var c = s[_i];
                if (IsDoubleQuote(c))
                {
                    _i++;
                    if (!End && IsDoubleQuote(s[_i])) { _i++; continue; }
                    return;
                }
                if (c == '`') { _i += 2; continue; }
                if (c == '$' && Peek(_i + 1) == '(') { SkipBalanced(_i + 1, '(', ')'); continue; }
                _i++;
            }
        }

        private void SkipBlockComment()
        {
            var end = s.IndexOf("#>", _i + 2, StringComparison.Ordinal);
            if (end < 0) throw Error("this <# comment is never closed", _i);
            _i = end + 2;
        }

        // ---- spacing

        private void SkipSpace(bool newlines, bool semicolons = false)
        {
            while (!End)
            {
                var c = s[_i];
                if (c is ' ' or '\t' or '﻿' or ' ') { _i++; continue; }
                if (c is '\r' or '\n') { if (!newlines) return; _i++; continue; }
                if (c == ';' && semicolons) { _i++; continue; }
                if (c == '`' && Peek(_i + 1) is '\r' or '\n') { _i++; if (Peek() == '\r') _i++; if (Peek() == '\n') _i++; continue; }
                if (c == '#') { while (!End && s[_i] is not ('\r' or '\n')) _i++; continue; }
                if (c == '<' && Peek(_i + 1) == '#') { SkipBlockComment(); continue; }
                return;
            }
        }

        private bool AtStatementEnd => End || s[_i] is '\r' or '\n' or ';' or '}' or ')';

        private bool End => _i >= s.Length;
        private char Peek() => _i < s.Length ? s[_i] : '\0';
        private char Peek(int at) => at < s.Length ? s[at] : '\0';

        private int LineAt(int at)
        {
            var line = 1;
            for (var j = 0; j < at && j < s.Length; j++) if (s[j] == '\n') line++;
            return line;
        }

        private PsDataException Error(string message, int at, bool fatal = false)
        {
            var lineStart = at > 0 ? s.LastIndexOf('\n', Math.Min(at, s.Length) - 1) + 1 : 0;
            return new PsDataException(message, LineAt(at), at - lineStart + 1) { Fatal = fatal };
        }
    }
}
