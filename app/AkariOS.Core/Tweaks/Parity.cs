namespace AkariOS.Core.Tweaks;

/// <summary>
/// What each app has that the other lacks (ADR 0007), as app/parity.txt: the native port's checklist.
/// PowerShell only: a Tweak whose file needs code and has no C# class, and a Group whose kind the native engine
/// can't run yet. Native only: a C# class with no src/Tweaks file.
/// </summary>
public static class Parity
{
    /// <summary>The kinds the native engine runs (N5 adds them).</summary>
    public static IReadOnlySet<string> NativeEntryKinds { get; } = new HashSet<string>();

    public sealed record Report(IReadOnlyList<Tweak> PowerShellOnly, IReadOnlyList<TweakGroup> GroupsPowerShellOnly, IReadOnlyList<string> NativeOnly);

    public static Report Of(LoadResult loaded, IReadOnlyDictionary<string, ITweakCode> codes)
    {
        static string Key(string section, string category, string id) => $"{section}/{category}/{id}";
        var psOnly = loaded.Tweaks.Where(t => !t.Native).OrderBy(t => Key(t.Section, t.Category, t.Id), StringComparer.Ordinal).ToList();
        var groups = loaded.Groups.Where(g => !NativeEntryKinds.Contains(g.EntryKind.Name)).OrderBy(g => Key(g.Section, g.Category, g.Id), StringComparer.Ordinal).ToList();
        var ids = loaded.Tweaks.Select(t => t.Id).Concat(loaded.Groups.Select(g => g.Id)).ToHashSet(StringComparer.Ordinal);
        var nativeOnly = codes.Keys.Where(k => !ids.Contains(k)).Order(StringComparer.Ordinal).ToList();
        return new Report(psOnly, groups, nativeOnly);
    }

    /// <summary>app/parity.txt's text (lines end in \n).</summary>
    public static string Text(Report r)
    {
        var lines = new List<string>
        {
            "# Tweak ids only one app has (ADR 0007): the native port's checklist. Written by the parity test:",
            "#   set AKARI_UPDATE_PARITY=1, then dotnet test --solution app\\AkariOS.Native.sln",
            "# PowerShell only = a src/Tweaks file with script blocks (or other code) and no C# class in AkariOS.Tweaks;",
            "# Native only = a C# class with no src/Tweaks file.",
            "",
            $"## PowerShell only: {r.PowerShellOnly.Count} Tweaks",
        };
        lines.AddRange(r.PowerShellOnly.Select(t => $"{t.Section}/{t.Category}  {t.Id}"));
        lines.Add("");
        lines.Add($"## PowerShell only: {r.GroupsPowerShellOnly.Count} Groups whose kind the native engine lacks");
        lines.AddRange(r.GroupsPowerShellOnly.Select(g => $"{g.Section}/{g.Category}  {g.Id}  ({g.EntryKind.Name})"));
        lines.Add("");
        lines.Add($"## Native only: {r.NativeOnly.Count}");
        lines.AddRange(r.NativeOnly);
        return string.Join('\n', lines) + "\n";
    }
}
