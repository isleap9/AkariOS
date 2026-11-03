using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks;

/// <summary>
/// Data a Tweak's C# reads out of the src/ files instead of copying it (ADR 0007: share, don't copy): a file's
/// top-level variables, a list joined in PowerShell, a list a helper function returns.
/// </summary>
public static partial class FileData
{
    /// <summary>A top-level <c>$name = …</c> of the Tweak's own file, as PsData reads it.</summary>
    public static object? Variable(Tweak t, TweakContext c, string name) =>
        PsData.Parse(c.Files.ReadText(t.Source)).Variables.TryGetValue(name, out var v) ? v : throw new InvalidOperationException($"{t.Source} has no ${name}");

    [GeneratedRegex(@"^(?<list>.*)\s-join\s+'(?<sep>[^']*)'\s*$", RegexOptions.Singleline)]
    private static partial Regex JoinPattern();

    /// <summary>A <c>@(…) -join 'x'</c> expression's text, joined as PowerShell joins it.</summary>
    public static string Joined(object? code)
    {
        var text = (code as PsCode)?.Text ?? throw new InvalidOperationException("not a -join expression");
        var m = JoinPattern().Match(text.Trim());
        if (!m.Success) throw new InvalidOperationException($"not a -join expression: {text}");
        return string.Join(m.Groups["sep"].Value, PsSemantics.AsList(PsData.ParseValue(m.Groups["list"].Value)).Select(PsSemantics.Text));
    }

    /// <summary>The list a helper file assigns to <c>$name = 'a', 'b', …</c> (up to its next statement), e.g. a hosts
    /// list inside a function: the file's text, not run.</summary>
    public static IReadOnlyList<string> AssignedList(ISourceFiles files, string path, string name)
    {
        var text = files.ReadText(path);
        var m = Regex.Match(text, $@"\${Regex.Escape(name)}\s*=\s*(?<list>(?:'[^']*'\s*,\s*)*'[^']*')", RegexOptions.Singleline);
        if (!m.Success) throw new InvalidOperationException($"{path} has no ${name} list");
        return PsSemantics.AsList(PsData.ParseValue(m.Groups["list"].Value)).Select(v => PsSemantics.Text(v)!).ToList();
    }

    /// <summary>A Registry row as a file writes one.</summary>
    public static RegistryRow Row(string path, string name, string type, object? value, object? windowsDefault = null) =>
        new(path, name, type, value, OsValue.Both(windowsDefault), IsKeyRow: false);

    /// <summary>A key row: the key exists (created empty) on Apply, deleted with its contents on Revert.</summary>
    public static RegistryRow KeyRow(string path) => new(path, null, null, "Key", OsValue.Both(null), IsKeyRow: true);

    /// <summary>The Tweak's services part, or a failure saying the engine has none.</summary>
    public static T Need<T>(T? part, string what) where T : class => TweakServices.Need(part, what);
}
