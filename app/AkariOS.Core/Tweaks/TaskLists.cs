using System.Globalization;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;

namespace AkariOS.Core.Tweaks;

/// <summary>A scheduled task on this PC (Get-AkariTasks): Path = its folder with a trailing \ ("\Microsoft\Windows\X\").</summary>
public sealed record TaskInfo(string Path, string Name, bool Enabled, string State, string Description, string Author);

/// <summary>A tasks.psd1 row: a folder, a name (a wildcard), who turns it off and why.</summary>
public sealed record TaskSuggestion(string Path, string Name, string Source, string Note);

/// <summary>The Scheduled tasks page's rules (the pure parts of src/UI/TasksPage.ps1, Oracle-tested).</summary>
public static class TaskLists
{
    /// <summary>$AkariTaskFilters: Microsoft = Windows' own folder, Other = the rest (apps' updaters).</summary>
    public static IReadOnlyList<string> Filters { get; } = ["All", "Enabled", "Disabled", "Microsoft", "Other"];

    /// <summary>$AkariTaskSuggestPath.</summary>
    public const string DataPath = "src/Tweaks/Advanced/Scheduled tasks/Files/tasks.psd1";

    /// <summary>Get-AkariTaskKey: its folder and name.</summary>
    public static string Key(TaskInfo t) => $"{t.Path}{t.Name}";

    /// <summary>Get-AkariTaskSuggestions: the tasks.psd1 rows.</summary>
    public static IReadOnlyList<TaskSuggestion> Suggestions(ISourceFiles files)
    {
        if (!files.Exists(DataPath)) return [];
        var d = PsData.Parse(files.ReadText(DataPath)).Value as PsHashtable;
        return PsSemantics.AsList(d?.Get("Tasks")).OfType<PsHashtable>().Select(r => new TaskSuggestion(
            PsSemantics.Text(r.Get("Path")) ?? "", PsSemantics.Text(r.Get("Name")) ?? "", PsSemantics.Text(r.Get("Source")) ?? "", PsSemantics.Text(r.Get("Note")) ?? "")).ToList();
    }

    /// <summary>Get-AkariTaskSuggestion: the first row that names the task, or null.</summary>
    public static TaskSuggestion? Suggestion(TaskInfo t, IEnumerable<TaskSuggestion> suggest) =>
        suggest.FirstOrDefault(r => string.Equals(t.Path, r.Path, StringComparison.OrdinalIgnoreCase) && PsSemantics.Like(t.Name, r.Name));

    private static readonly StringComparer ByName = StringComparer.Create(CultureInfo.CurrentCulture, ignoreCase: true);

    /// <summary>Get-AkariTaskView: the tasks the filter and the search (name, folder, description) leave, by folder then
    /// name; with suggest, only the tasks it names (null = every task).</summary>
    public static IReadOnlyList<TaskInfo> View(IEnumerable<TaskInfo> tasks, string filter, string query, IReadOnlyList<TaskSuggestion>? suggest)
    {
        var q = query.Trim();
        return tasks.Where(t =>
        {
            if (suggest is not null && Suggestion(t, suggest) is null) return false;
            var hit = filter switch
            {
                "Enabled" => t.Enabled,
                "Disabled" => !t.Enabled,
                "Microsoft" => PsSemantics.Like(t.Path, @"\Microsoft\*"),
                "Other" => !PsSemantics.Like(t.Path, @"\Microsoft\*"),
                _ => true,
            };
            return hit && (q.Length == 0 || $"{t.Name} {t.Path} {t.Description}".Contains(q, StringComparison.OrdinalIgnoreCase));
        }).OrderBy(t => t.Path, ByName).ThenBy(t => t.Name, ByName).ToList();
    }
}
