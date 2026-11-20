using System.Text.RegularExpressions;

namespace AkariOS.App.Shell;

/// <summary>A piece of a name: its text, and whether it is the search's match.</summary>
public sealed record TextPart(string Text, bool Hit);

/// <summary>A card's name with the search query in it (Set-AkariCardHighlight): what the view shows, the match in the
/// accent and semibold.</summary>
public sealed record Highlighted(string Text, string Query)
{
    public IReadOnlyList<TextPart> Parts => TextMatch.Split(Text, Query);
}

/// <summary>Set-AkariCardHighlight's split, pure: the name cut around every match of the query, ignoring case.</summary>
public static class TextMatch
{
    public static IReadOnlyList<TextPart> Split(string text, string query)
    {
        query = query.Trim();
        if (query.Length == 0) return [new(text, false)];
        return [.. Regex.Split(text, "(" + Regex.Escape(query) + ")", RegexOptions.IgnoreCase)
            .Where(p => p.Length > 0)
            .Select(p => new TextPart(p, string.Equals(p, query, StringComparison.OrdinalIgnoreCase)))];
    }
}
