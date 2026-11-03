using System.Text;
using System.Text.RegularExpressions;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>
/// src/Tweaks/Customize/Apps/TerminalCloseTabs.ps1 (+ Files/TerminalSettings.ps1): confirmCloseAllTabs in the real
/// user's Windows Terminal settings.json, edited as text (the file may hold comments): Apply adds
/// "confirmCloseAllTabs": false after the first "{" (or sets an existing value), Revert removes the line. Unknown while
/// Terminal has no settings file.
/// </summary>
[TweakCode("apps-terminal-no-close-tabs-warning")]
public sealed partial class TerminalCloseTabs : ITweakCode
{
    // PowerShell's -match / -replace ignore case; [regex]::Match doesn't
    [GeneratedRegex(@"""confirmCloseAllTabs""\s*:\s*false", RegexOptions.IgnoreCase)]
    private static partial Regex IsFalse();

    [GeneratedRegex(@"""confirmCloseAllTabs""\s*:\s*(?!true)", RegexOptions.IgnoreCase)]
    private static partial Regex IsOther();

    [GeneratedRegex(@"(""confirmCloseAllTabs""\s*:\s*)(true|false)", RegexOptions.IgnoreCase)]
    private static partial Regex Value();

    [GeneratedRegex(@"(?m)^[ \t]*""confirmCloseAllTabs""[ \t]*:[ \t]*(true|false)[ \t]*(,?)[ \t]*\r?\n")]
    private static partial Regex Line();

    [GeneratedRegex(@",(\s*)$", RegexOptions.IgnoreCase)]
    private static partial Regex TrailingComma();

    public static string Path(TweakContext c) =>
        System.IO.Path.Combine(FileData.UserFolder(c, "Local AppData"), @"Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json");

    private static string? Read(TweakContext c) => File.Exists(Path(c)) ? File.ReadAllText(Path(c)) : null;

    /// <summary>The Detect block's verdict on the file's text.</summary>
    public static TweakState StateOf(string? text) =>
        text is null ? TweakState.Unknown : IsFalse().IsMatch(text) ? TweakState.Optimized : IsOther().IsMatch(text) ? TweakState.Custom : TweakState.Default;

    /// <summary>Set-AkariTerminalCloseTabs: the text with the warning off (noWarning) or the line removed.</summary>
    public static string Edit(string text, bool noWarning)
    {
        if (noWarning)
        {
            if (Value().IsMatch(text)) return Value().Replace(text, "${1}false");
            var nl = text.Contains("\r\n", StringComparison.Ordinal) ? "\r\n" : "\n";
            var i = text.IndexOf('{');
            if (i < 0) throw new InvalidOperationException("Windows Terminal's settings file is not a JSON object");
            var rest = text[(i + 1)..];
            var empty = rest.Trim() == "}";
            return text[..(i + 1)] + nl + "    \"confirmCloseAllTabs\": false" + (empty ? "" : ",") + (rest.StartsWith(nl, StringComparison.Ordinal) ? "" : nl) + rest;
        }
        var m = Line().Match(text);
        if (!m.Success) return text;
        var before = text[..m.Index];
        var after = text[(m.Index + m.Length)..];
        // the last property: the one before it loses its comma
        if (m.Groups[2].Value.Length == 0) before = TrailingComma().Replace(before, "$1");
        return before + after;
    }

    public TweakState Detect(Tweak tweak, TweakContext c) => StateOf(Read(c));

    public void Apply(Tweak tweak, TweakContext c, object? value) => Write(c, true);

    public void Revert(Tweak tweak, TweakContext c, object? value) => Write(c, false);

    private static void Write(TweakContext c, bool noWarning)
    {
        var text = Read(c) ?? throw new InvalidOperationException("Windows Terminal has no settings file yet (open it once, then try again)");
        var edited = Edit(text, noWarning);
        // the PowerShell block returns early without writing when there's no line to remove
        if (!noWarning && ReferenceEquals(edited, text)) return;
        File.WriteAllText(Path(c), edited, new UTF8Encoding(false));
    }
}
