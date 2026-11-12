using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native Services and Scheduled tasks lists against src\UI\ServicesPage.ps1 / TasksPage.ps1
/// (Oracle/Export-ServiceLists.ps1) on made-up services and tasks and the real services.psd1 / tasks.psd1: the same
/// start types, filters, defaults, suggestions, views (every filter, search, Show all or not), buttons and questions.
/// </summary>
public class ServiceListsOracleTests
{
    private static readonly string[] Queries = ["print", "UPDATE", "zzz"];

    internal static readonly ServiceInfo[] Services =
    [
        new("BITS", "Background Intelligent Transfer Service", "Transfers files in the background", "Automatic", "Running", true),
        new("cbdhsvc_4f2a1", "Clipboard User Service_4f2a1", "Clipboard", "Manual", "Stopped", false),
        new("RpcSs", "Remote Procedure Call (RPC)", "The RPCSS service", "Automatic", "Running", false),
        new("Spooler", "Print Spooler", "Spools print jobs", "AutomaticDelayed", "Running", true),
        new("DiagTrack", "Connected User Experiences and Telemetry", "", "Disabled", "Stopped", false),
        new("Contoso", "Contoso Driver", "A boot driver", "Boot", "Stopped", false),
        new("UserManager", "User Manager", "Needed to sign in", "Automatic", "Running", true),
        new("wuauserv", "Windows Update", "Updates Windows", "Manual", "Stopped", false),
    ];

    internal static readonly TaskInfo[] Tasks =
    [
        new(@"\Microsoft\Windows\UpdateOrchestrator\", "Schedule Scan", true, "Ready", "Scans for updates", "Microsoft"),
        new(@"\Microsoft\Windows\Application Experience\", "ProgramDataUpdater", false, "Disabled", "Telemetry data", "Microsoft Corporation"),
        new(@"\", "GoogleUpdateTaskMachineUA", true, "Ready", "Keeps Google software up to date", "Google"),
        new(@"\Microsoft\Windows\Defrag\", "ScheduledDefrag", true, "Running", "Optimizes drives", ""),
        new(@"\Microsoft\Windows\Maps\", "MapsUpdateTask", true, "Ready", "Map updates", ""),
    ];

    private static readonly Lazy<JsonElement> PowerShell = new(() =>
    {
        var dir = Path.Combine(Path.GetTempPath(), $"akari-svc-{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var svc = Path.Combine(dir, "services.json");
            var tasks = Path.Combine(dir, "tasks.json");
            File.WriteAllText(svc, JsonSerializer.Serialize(Services));
            File.WriteAllText(tasks, JsonSerializer.Serialize(Tasks));
            return Oracle.Run("Export-ServiceLists.ps1", ["-Src", Repo.Src, "-Services", svc, "-Tasks", tasks, "-Queries", string.Join(",", Queries)]);
        }
        finally { Directory.Delete(dir, recursive: true); }
    });

    private static readonly ISourceFiles Files = new FolderSourceFiles(Repo.Root);

    private static JsonElement Ps(string name) => PowerShell.Value.GetProperty(name);

    private static List<string> Strings(JsonElement a) => a.ValueKind == JsonValueKind.Array ? a.EnumerateArray().Select(e => e.GetString()!).ToList() : [];

    [Fact]
    public void The_same_start_types_filters_and_critical_services()
    {
        Assert.Equal(Strings(Ps("StartTypes")), ServiceLists.StartTypes.Select(p => $"{p.Key}={p.Value}"));
        Assert.Equal(Strings(Ps("Filters")), ServiceLists.Filters);
        Assert.Equal(Strings(Ps("TaskFilters")), TaskLists.Filters);
        Assert.Equal(Strings(Ps("Critical")), ServiceLists.Critical);
        Assert.Equal(Strings(Ps("Labels")), new[] { 2, 3, 4, 1 }.Select(ServiceLists.StartLabel));
    }

    [Fact]
    public void The_same_start_type_conversions()
    {
        foreach (var p in Ps("Types").EnumerateObject())
        {
            var (mode, delayed) = (p.Name.Split('|')[0], p.Name.Split('|')[1] == "True");
            Assert.Equal(p.Value.GetString(), ServiceLists.StartType(mode, delayed));
        }
        foreach (var p in Ps("Values").EnumerateObject())
        {
            var (start, delayed) = ServiceLists.StartValue(p.Name);
            Assert.Equal(p.Value.GetString(), $"{start}|{delayed}");
        }
        Assert.Throws<ArgumentException>(() => ServiceLists.StartValue("Boot"));
    }

    [Fact]
    public void The_same_defaults_and_suggestions_from_services_psd1()
    {
        var defaults = ServiceLists.Defaults(Files);
        Assert.Equal(Ps("Defaults").EnumerateObject().Select(p => $"{p.Name}={p.Value.GetInt32()}").Order(StringComparer.Ordinal),
            defaults.Select(p => $"{p.Key}={p.Value}").Order(StringComparer.Ordinal));
        var suggest = ServiceLists.Suggestions(Files);
        Assert.Equal(Ps("Suggestions").EnumerateObject().Select(p => $"{p.Name}={string.Join(" + ", Strings(p.Value))}").Order(StringComparer.Ordinal),
            suggest.Select(p => $"{p.Key}={string.Join(" + ", p.Value)}").Order(StringComparer.Ordinal));
    }

    [Fact]
    public void The_same_service_views()
    {
        var (defaults, suggest) = (ServiceLists.Defaults(Files), ServiceLists.Suggestions(Files));
        // not trivially equal: some services are suggested, some aren't, the Changed filter finds one
        Assert.InRange(ServiceLists.View(Services, "All", "", defaults, suggest).Count, 1, Services.Length - 1);
        Assert.NotEmpty(ServiceLists.View(Services, "Changed", "", defaults, null));
        foreach (var p in Ps("ServiceViews").EnumerateObject())
        {
            var k = p.Name.Split('|');
            Assert.True(Strings(p.Value).SequenceEqual(ServiceLists.View(Services, k[0], k[1], defaults, k[2] == "all" ? null : suggest).Select(s => s.Name)), p.Name);
        }
    }

    [Fact]
    public void The_same_row_details_and_questions()
    {
        var (defaults, suggest) = (ServiceLists.Defaults(Files), ServiceLists.Suggestions(Files));
        foreach (var s in Services)
        {
            var ps = Ps("PerService").GetProperty(s.Name);
            Assert.Equal(ps.GetProperty("Template").GetString(), ServiceLists.Template(s.Name));
            Assert.Equal(ps.GetProperty("Default").ValueKind == JsonValueKind.Null ? null : ps.GetProperty("Default").GetInt32(), ServiceLists.Default(s, defaults));
            Assert.Equal(Strings(ps.GetProperty("Suggestion")), ServiceLists.Suggestion(s, suggest));
            Assert.Equal(ps.GetProperty("Changed").GetBoolean(), ServiceLists.Changed(s, defaults));
            Assert.Equal(ps.GetProperty("Action").GetString(), ServiceLists.Action(s));
            Assert.Equal(ps.GetProperty("Disable").GetString(), ServiceLists.Confirm(s, "StartType", "Disabled"));
            Assert.Equal(ps.GetProperty("Manual").GetString(), ServiceLists.Confirm(s, "StartType", "Manual"));
            Assert.Equal(ps.GetProperty("Stop").GetString(), ServiceLists.Confirm(s, "Control", "Stop"));
            Assert.Equal(ps.GetProperty("Start").GetString(), ServiceLists.Confirm(s, "Control", "Start"));
        }
    }

    [Fact]
    public void The_same_task_views_and_suggestions()
    {
        var suggest = TaskLists.Suggestions(Files);
        Assert.InRange(TaskLists.View(Tasks, "All", "", suggest).Count, 1, Tasks.Length - 1);
        foreach (var p in Ps("TaskViews").EnumerateObject())
        {
            var k = p.Name.Split('|');
            Assert.True(Strings(p.Value).SequenceEqual(TaskLists.View(Tasks, k[0], k[1], k[2] == "all" ? null : suggest).Select(TaskLists.Key)), p.Name);
        }
        foreach (var t in Tasks)
        {
            var r = TaskLists.Suggestion(t, suggest);
            Assert.Equal(Ps("PerTask").GetProperty(TaskLists.Key(t)).GetString(), r is null ? "" : $"{r.Source} ({r.Note})");
        }
    }
}
