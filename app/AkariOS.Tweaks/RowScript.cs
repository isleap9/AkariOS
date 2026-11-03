using System.Text;
using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks;

/// <summary>
/// Registry rows a Tweak file builds with code, read out of the file instead of copied (ADR 0007: share, don't copy).
/// It evaluates the few forms the files use, never running PowerShell: row hashtables, <c>$name = value</c>,
/// <c>&amp; $helper arg… -Switch</c> (a top-level <c>$helper = { param(…) … }</c>, the caller's variables seen inside),
/// <c>foreach ($x in list) { … }</c> and <c>if ($x) { … }</c> or <c>if (Get-AkariRegKey "…") { … }</c> (a key that
/// exists). Values go through PsData, so strings, "$var" expansion, numbers and lists read as the Loader reads them.
/// Anything else throws; the rows oracle (Oracle/Export-TweakRows.ps1) checks the result against PowerShell's.
/// </summary>
public static partial class RowScript
{
    /// <summary>The Tweak's Registry rows: its file's Registry expression, with the file's variables.</summary>
    public static IReadOnlyList<RegistryRow> Rows(Tweak t, TweakContext c)
    {
        var file = PsData.Parse(c.Files.ReadText(t.Source));
        var env = new Dictionary<string, object?>(file.Variables, StringComparer.OrdinalIgnoreCase);
        // PsData reads @(…) element by element: a row it could read is data already, the rest is code to evaluate
        var rows = new List<PsHashtable>();
        foreach (var e in PsSemantics.AsList(t.Fields.Get("Registry")))
            rows.AddRange(e switch
            {
                PsHashtable h => [h],
                PsCode code => Eval(code.Text, env, _ => throw new NotSupportedException("no key test in a Registry list")),
                _ => throw new InvalidOperationException($"{t.Source}: a Registry element that is neither a row nor code"),
            });
        return ToRows(rows, t.Source);
    }

    /// <summary>The rows a helper function of a src/ file returns, keys tested on the registry.</summary>
    public static IReadOnlyList<RegistryRow> Function(TweakContext c, string path, string name)
    {
        var text = c.Files.ReadText(path);
        var m = Regex.Match(text, $@"function\s+{Regex.Escape(name)}\s*\{{");
        if (!m.Success) throw new InvalidOperationException($"{path} has no function {name}");
        var open = m.Index + m.Length - 1;
        var body = text[(open + 1)..Close(text, open)];
        return ToRows(Eval(body, new(StringComparer.OrdinalIgnoreCase), c.Registry.KeyExists), path);
    }

    private static List<RegistryRow> ToRows(List<PsHashtable> rows, string source) =>
        rows.Select(h => Loader.ToRow(h) ?? throw new InvalidOperationException($"{source}: a row with no Path")).ToList();

    [GeneratedRegex(@"^\$(?<n>[A-Za-z_]\w*)\s*=(?!=)\s*(?<v>.+)$", RegexOptions.Singleline)]
    private static partial Regex Assignment();

    [GeneratedRegex(@"^&\s*\$(?<n>[A-Za-z_]\w*)(?<args>.*)$", RegexOptions.Singleline)]
    private static partial Regex Call();

    [GeneratedRegex(@"^\s*\$(?<v>[A-Za-z_]\w*)\s+in\s+(?<list>.+)$", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex ForeachHeader();

    [GeneratedRegex(@"^\s*\$(?<v>[A-Za-z_]\w*)\s*$")]
    private static partial Regex VariableTest();

    [GeneratedRegex(@"^\s*Get-AkariRegKey\s+(?<arg>.+?)\s*$", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex KeyTest();

    [GeneratedRegex(@"^(?<kw>foreach|if)\s*\(", RegexOptions.IgnoreCase)]
    private static partial Regex Keyword();

    private static List<PsHashtable> Eval(string body, Dictionary<string, object?> env, Func<string, bool> keyExists)
    {
        var rows = new List<PsHashtable>();
        foreach (var st in Statements(body))
        {
            if (st.StartsWith("@{", StringComparison.Ordinal))
            {
                rows.Add(Value(st, env) as PsHashtable ?? throw new InvalidOperationException($"not a row: {st}"));
                continue;
            }
            if (Keyword().Match(st) is { Success: true } kw)
            {
                var open = kw.Length - 1;
                var close = Close(st, open);
                var head = st[(open + 1)..close];
                var braceAt = st.IndexOf('{', close);
                if (braceAt < 0 || st[(close + 1)..braceAt].Trim().Length > 0) throw new InvalidOperationException($"not a block: {st}");
                var end = Close(st, braceAt);
                if (st[(end + 1)..].Trim().Length > 0) throw new NotSupportedException($"more after the block: {st}");
                var inner = st[(braceAt + 1)..end];
                if (kw.Groups["kw"].Value.Equals("foreach", StringComparison.OrdinalIgnoreCase))
                {
                    var h = ForeachHeader().Match(head);
                    if (!h.Success) throw new NotSupportedException($"foreach ({head})");
                    foreach (var item in PsSemantics.AsList(Value(h.Groups["list"].Value, env)))
                        rows.AddRange(Eval(inner, new(env, StringComparer.OrdinalIgnoreCase) { [h.Groups["v"].Value] = item }, keyExists));
                }
                else if (Test(head, env, keyExists)) rows.AddRange(Eval(inner, env, keyExists));
                continue;
            }
            if (Call().Match(st) is { Success: true } call)
            {
                rows.AddRange(Invoke(call.Groups["n"].Value, call.Groups["args"].Value, env, keyExists));
                continue;
            }
            if (Assignment().Match(st) is { Success: true } a)
            {
                env[a.Groups["n"].Value] = Value(a.Groups["v"].Value, env);
                continue;
            }
            throw new NotSupportedException($"a statement RowScript doesn't read: {st}");
        }
        return rows;
    }

    private static bool Test(string head, Dictionary<string, object?> env, Func<string, bool> keyExists)
    {
        if (VariableTest().Match(head) is { Success: true } v) return PsSemantics.Truthy(env.GetValueOrDefault(v.Groups["v"].Value));
        if (KeyTest().Match(head) is { Success: true } k) return keyExists(PsSemantics.Text(Value(k.Groups["arg"].Value, env)) ?? "");
        throw new NotSupportedException($"if ({head})");
    }

    // & $helper 'a' $b -Switch: positional arguments in param order, switches by name
    private static List<PsHashtable> Invoke(string name, string args, Dictionary<string, object?> env, Func<string, bool> keyExists)
    {
        var block = env.GetValueOrDefault(name) as PsScriptBlock ?? throw new InvalidOperationException($"${name} is not a script block");
        var text = block.Text.TrimStart();
        var p = Regex.Match(text, @"^param\s*\(", RegexOptions.IgnoreCase);
        if (!p.Success) throw new NotSupportedException($"${name} has no param()");
        var close = Close(text, p.Length - 1);
        var parameters = Split(text[p.Length..close], ',').Select(x =>
        {
            var m = Regex.Match(x.Trim(), @"^(?<sw>\[switch\])?\s*\$(?<n>[A-Za-z_]\w*)$", RegexOptions.IgnoreCase);
            return m.Success ? (Name: m.Groups["n"].Value, Switch: m.Groups["sw"].Success) : throw new NotSupportedException($"param {x}");
        }).ToList();
        var scope = new Dictionary<string, object?>(env, StringComparer.OrdinalIgnoreCase);
        foreach (var q in parameters) scope[q.Name] = q.Switch ? false : null;
        var positional = parameters.Where(q => !q.Switch).Select(q => q.Name).ToList();
        var next = 0;
        foreach (var arg in Split(args, ' ', '\t', '\r', '\n'))
        {
            if (Regex.Match(arg, @"^-(?<n>[A-Za-z_]\w*)$") is { Success: true } sw)
            {
                var q = parameters.FirstOrDefault(x => x.Switch && x.Name.Equals(sw.Groups["n"].Value, StringComparison.OrdinalIgnoreCase));
                if (q.Name is null) throw new NotSupportedException($"-{sw.Groups["n"].Value} isn't a switch of ${name}");
                scope[q.Name] = true;
                continue;
            }
            if (next >= positional.Count) throw new InvalidOperationException($"too many arguments to ${name}");
            scope[positional[next++]] = Value(arg, env);
        }
        return Eval(text[(close + 1)..], scope, keyExists);
    }

    /// <summary>A value as PsData reads it, the variables written in front of it as literals.</summary>
    private static object? Value(string text, Dictionary<string, object?> env)
    {
        var b = new StringBuilder();
        foreach (var (k, v) in env)
            if (Literal(v) is { } lit) b.Append('$').Append(k).Append(" = ").Append(lit).Append('\n');
        return PsData.Parse(b.Append(text).ToString()).Value;
    }

    private static string? Literal(object? v) => v switch
    {
        null => "$null",
        bool x => x ? "$true" : "$false",
        string s => "'" + Regex.Replace(s, "['‘’‚‛]", "$0$0") + "'",
        int or long or double or decimal => Convert.ToString(v, System.Globalization.CultureInfo.InvariantCulture),
        object?[] a when a.All(x => Literal(x) is not null) => "@(" + string.Join(", ", a.Select(Literal)) + ")",
        _ => null,
    };

    // ---- the text: statements at depth 0, matching brackets, quote-aware

    /// <summary>The statements of a body: split at a newline or ';' outside brackets and strings (a line ending
    /// with ',' goes on); comments left out.</summary>
    private static List<string> Statements(string body)
    {
        var list = new List<string>();
        var cur = new StringBuilder();
        void Flush()
        {
            var st = cur.ToString().Trim();
            if (st.Length > 0) list.Add(st);
            cur.Clear();
        }
        var depth = 0;
        for (var i = 0; i < body.Length; i++)
        {
            var c = body[i];
            if (c is '\'' or '"') { var end = SkipString(body, i); cur.Append(body, i, end - i + 1); i = end; continue; }
            if (c == '#' && depth == 0) { while (i < body.Length && body[i] != '\n') i++; i--; continue; }
            if (c is '(' or '{' or '[') depth++;
            else if (c is ')' or '}' or ']') depth--;
            if (depth == 0 && (c == ';' || c == '\n') && !cur.ToString().TrimEnd().EndsWith(',')) { Flush(); continue; }
            cur.Append(c);
        }
        Flush();
        return list;
    }

    /// <summary>The index of the bracket closing the one at <paramref name="open"/>.</summary>
    private static int Close(string s, int open)
    {
        var depth = 0;
        for (var i = open; i < s.Length; i++)
        {
            var c = s[i];
            if (c is '\'' or '"') { i = SkipString(s, i); continue; }
            if (c is '(' or '{' or '[') depth++;
            else if (c is ')' or '}' or ']' && --depth == 0) return i;
        }
        throw new InvalidOperationException("an unclosed bracket");
    }

    /// <summary>The parts of a text split at the separators outside brackets and strings (empty ones dropped).</summary>
    private static List<string> Split(string s, params char[] separators)
    {
        var parts = new List<string>();
        var cur = new StringBuilder();
        var depth = 0;
        for (var i = 0; i < s.Length; i++)
        {
            var c = s[i];
            if (c is '\'' or '"') { var end = SkipString(s, i); cur.Append(s, i, end - i + 1); i = end; continue; }
            if (c is '(' or '{' or '[') depth++;
            else if (c is ')' or '}' or ']') depth--;
            if (depth == 0 && separators.Contains(c)) { if (cur.ToString().Trim().Length > 0) parts.Add(cur.ToString().Trim()); cur.Clear(); continue; }
            cur.Append(c);
        }
        if (cur.ToString().Trim().Length > 0) parts.Add(cur.ToString().Trim());
        return parts;
    }

    /// <summary>The index of a string's closing quote: '' inside single quotes, "" and `x inside double quotes.</summary>
    private static int SkipString(string s, int at)
    {
        var q = s[at];
        for (var i = at + 1; i < s.Length; i++)
        {
            if (q == '"' && s[i] == '`') { i++; continue; }
            if (s[i] != q) continue;
            if (i + 1 < s.Length && s[i + 1] == q) { i++; continue; }
            return i;
        }
        throw new InvalidOperationException("an unclosed string");
    }
}
