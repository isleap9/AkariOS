using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace AkariOS.Core.Data;

/// <summary>How PowerShell treats values in the checks the PowerShell app's Loader makes, for the native one.</summary>
public static class PsSemantics
{
    /// <summary>PowerShell's truth: null, false, 0, "" and an empty list are false; a one-item list is its item's.</summary>
    public static bool Truthy(object? v) => v switch
    {
        null => false,
        bool b => b,
        string s => s.Length > 0,
        int n => n != 0,
        long n => n != 0,
        ulong n => n != 0,
        uint n => n != 0,
        double d => d != 0,
        decimal m => m != 0,
        object?[] a => a.Length switch { 0 => false, 1 => Truthy(a[0]), _ => true },
        _ => true,
    };

    /// <summary>@($v): a list as it is, null as empty, anything else as one item.</summary>
    public static IReadOnlyList<object?> AsList(object? v) => v switch
    {
        null => [],
        object?[] a => a,
        _ => [v],
    };

    /// <summary>The text of a value (a string, or the text a number, bool or code shows as).</summary>
    public static string? Text(object? v) => v switch
    {
        null => null,
        string s => s,
        bool b => b ? "True" : "False",
        PsCode c => c.Text,
        IFormattable f => f.ToString(null, CultureInfo.InvariantCulture),
        _ => v.ToString(),
    };

    /// <summary>PowerShell's -eq for the values data files hold: numbers by value, text ignoring case.</summary>
    public static bool LooseEquals(object? a, object? b)
    {
        if (a is null || b is null) return a is null && b is null;
        if (IsNumber(a) && IsNumber(b)) return Convert.ToDecimal(a, CultureInfo.InvariantCulture) == Convert.ToDecimal(b, CultureInfo.InvariantCulture);
        if (IsNumber(a) && b is string sb) return decimal.TryParse(sb, NumberStyles.Any, CultureInfo.InvariantCulture, out var nb) && nb == Convert.ToDecimal(a, CultureInfo.InvariantCulture);
        if (a is string sa && IsNumber(b)) return LooseEquals(b, sa);
        return string.Equals(Text(a), Text(b), StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsNumber(object? v) => v is int or long or ulong or uint or double or decimal or byte;

    /// <summary>PowerShell's -like: * ? [abc] [a-z], ` escapes, ignoring case.</summary>
    public static bool Like(string? text, string? pattern)
    {
        if (text is null || pattern is null) return false;
        var b = new StringBuilder("^");
        for (var i = 0; i < pattern.Length; i++)
        {
            var c = pattern[i];
            switch (c)
            {
                case '*': b.Append(".*"); break;
                case '?': b.Append('.'); break;
                case '`' when i + 1 < pattern.Length: b.Append(Regex.Escape(pattern[++i].ToString())); break;
                case '[':
                    var close = pattern.IndexOf(']', i + 1);
                    if (close < 0) { b.Append(@"\["); break; }
                    b.Append('[').Append(pattern[(i + 1)..close].Replace(@"\", @"\\")).Append(']');
                    i = close;
                    break;
                default: b.Append(Regex.Escape(c.ToString())); break;
            }
        }
        return Regex.IsMatch(text, b.Append('$').ToString(), RegexOptions.IgnoreCase | RegexOptions.Singleline);
    }
}
