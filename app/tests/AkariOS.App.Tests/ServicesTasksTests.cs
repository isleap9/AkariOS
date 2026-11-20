using AkariOS.App.ViewModels;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Tests;

/// <summary>The Services and Scheduled tasks lists (src/UI/ServicesPage.ps1, TasksPage.ps1) on the real Tweak files
/// and lists, the PC's services and tasks faked; changes through the Catalogue's queue, the restore point first.</summary>
public sealed class ServicesTasksTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    // BITS and Spooler are FR33THY's / ZOICWARE's, Contoso isn't; RpcSs is one Windows needs
    private AppTest Pc()
    {
        var t = _h.Make();
        t.Services.List.AddRange([
            new ServiceInfo("BITS", "Background Intelligent Transfer Service", "Transfers files", "Automatic", "Running", true),
            new ServiceInfo("Spooler", "Print Spooler", "Spools print jobs", "Automatic", "Stopped", true),
            new ServiceInfo("Contoso", "Contoso Helper", "Not in any list", "Manual", "Stopped", false),
            new ServiceInfo("RpcSs", "Remote Procedure Call (RPC)", "RPC", "Automatic", "Running", false),
        ]);
        foreach (var n in new[] { "BITS", "Spooler", "Contoso", "RpcSs" })
            t.Engine.Registry.SetValue($@"{ServiceStart.Root}\{n}", "Start", 2, "DWord");
        t.Tasks.List.AddRange([
            new TaskInfo(@"\Microsoft\Windows\UpdateOrchestrator\", "Schedule Scan", true, "Ready", "Scans for updates", "Microsoft"),
            new TaskInfo(@"\Microsoft\Windows\Application Experience\", "ProgramDataUpdater", true, "Ready", "Telemetry", "Microsoft"),
            new TaskInfo(@"\", "ContosoUpdate", true, "Ready", "An app's updater", "Contoso"),
        ]);
        return t;
    }

    private static object? Pick(ServiceRowViewModel row, string start) => row.Choices.First(c => c.Value as string == start);

    [Fact]
    public void The_advanced_section_shows_the_lists_under_their_tweaks()
    {
        var t = Pc();
        // each list on its Category's own page, under its Tweaks
        var services = t.Page("Catalogue:Advanced/Services").Groups.Single();
        Assert.Equal(CataloguePageViewModel.ServicesKey, services.Key);
        Assert.Same(t.ServiceList, services.Services);
        Assert.Contains(services.Cards, c => c.Id == "advanced-services-off");
        var tasks = t.Page("Catalogue:Advanced/Scheduled tasks").Groups.Single();
        Assert.Equal(CataloguePageViewModel.TasksKey, tasks.Key);
        Assert.Same(t.TaskList, tasks.Tasks);
        Assert.False(tasks.HasServices);
        Assert.All(t.Page("Catalogue:Advanced/Security").Groups, g => Assert.False(g.HasServices || g.HasTasks));
        // the search results show Tweaks only
        Assert.All(t.Page("", "service").Groups, g => Assert.False(g.HasServices || g.HasTasks));
    }

    [Fact]
    public void The_services_list_shows_what_fr33thy_and_zoicware_change_and_show_all_lists_every_one()
    {
        var t = Pc();
        t.Page("Catalogue:Advanced/Services");
        var list = t.ServiceList;
        Assert.Equal(["BITS", "Spooler"], list.Shown.Select(r => r.Name));
        Assert.Equal("2 services FR33THY and ZOICWARE change", list.CountText);
        Assert.Equal(1, t.Services.Reads);
        list.ShowAll = true;
        Assert.Equal(["BITS", "Contoso", "Spooler", "RpcSs"], list.Shown.Select(r => r.Name));
        Assert.Equal("4 services", list.CountText);
        list.Filter = "Running";
        Assert.Equal(["BITS", "RpcSs"], list.Shown.Select(r => r.Name));
        Assert.Equal("2 of 4 services", list.CountText);
        // its own search; the list isn't read again
        list.Filter = "All";
        list.Query = "print";
        Assert.Equal(["Spooler"], list.Shown.Select(r => r.Name));
        list.Query = "zzz";
        Assert.Equal((true, "No service matches."), (list.HasMessage, list.Message));
        t.Page("Catalogue:Advanced/Services");
        Assert.Equal(1, t.Services.Reads);
        list.Refresh();
        Assert.Equal(2, t.Services.Reads);
    }

    [Fact]
    public void A_startup_type_is_written_to_the_service_key_after_the_restore_point()
    {
        var t = Pc();
        t.Page("Catalogue:Advanced/Services");
        var row = t.ServiceList.Rows["BITS"];
        Assert.Equal("Automatic", (row.SelectedStart as ChoiceItem)?.Value);
        row.SelectedStart = Pick(row, "Disabled");
        Assert.Equal(4u, t.Engine.Registry.GetValue($@"{ServiceStart.Root}\BITS", "Start"));
        Assert.Equal(0u, t.Engine.Registry.GetValue($@"{ServiceStart.Root}\BITS", "DelayedAutostart"));
        Assert.Single(t.Points.Points);
        Assert.Equal(("", false), (row.Error, row.HasStateLine));
        Assert.Contains("Background Intelligent Transfer Service: startup type Disabled", ((MemoryLog)t.Engine.Log).Lines);
    }

    [Fact]
    public void Start_and_stop_act_on_the_service_and_read_it_back()
    {
        var t = Pc();
        t.Page("Catalogue:Advanced/Services");
        var row = t.ServiceList.Rows["BITS"];
        Assert.Equal(("Stop", true), (row.ActionText, row.IsRunning));
        row.ActCommand.Execute(null);
        Assert.Equal(["Stop BITS"], t.Services.Calls);
        Assert.Equal(("Start", "Stopped", false), (row.ActionText, row.StatusText, row.IsRunning));
    }

    [Fact]
    public void Disabling_a_service_windows_needs_asks_first()
    {
        var t = Pc();
        t.Page("Catalogue:Advanced/Services");
        t.ServiceList.ShowAll = true;
        var row = t.ServiceList.Rows["RpcSs"];
        row.SelectedStart = Pick(row, "Disabled");
        Assert.Single(t.Dialogs.Asked);
        Assert.Contains("is a service Windows needs", t.Dialogs.Asked[0]);
        Assert.Equal(2u, t.Engine.Registry.GetValue($@"{ServiceStart.Root}\RpcSs", "Start"));
        // the dropdown goes back
        Assert.Equal("Automatic", (row.SelectedStart as ChoiceItem)?.Value);
    }

    [Fact]
    public void A_change_that_fails_says_why_on_its_row()
    {
        var t = Pc();
        t.Engine.Registry.DeleteKey($@"{ServiceStart.Root}\Spooler");
        t.Page("Catalogue:Advanced/Services");
        var row = t.ServiceList.Rows["Spooler"];
        row.SelectedStart = Pick(row, "Manual");
        Assert.Equal(("no service named Spooler", "Failed: no service named Spooler", true), (row.Error, row.StateLine, row.IsError));
    }

    [Fact]
    public void The_tasks_list_shows_what_fr33thy_and_zoicware_turn_off_and_switches_them()
    {
        var t = Pc();
        t.Page("Catalogue:Advanced/Scheduled tasks");
        var list = t.TaskList;
        Assert.Contains(@"\Microsoft\Windows\UpdateOrchestrator\Schedule Scan", list.Shown.Select(r => r.Key));
        Assert.DoesNotContain(@"\ContosoUpdate", list.Shown.Select(r => r.Key));
        list.ShowAll = true;
        Assert.Contains(@"\ContosoUpdate", list.Shown.Select(r => r.Key));

        // as admin
        var row = list.Rows[@"\Microsoft\Windows\Application Experience\ProgramDataUpdater"];
        Assert.True(row.HasSuggest);
        row.IsOn = false;
        Assert.Equal([@"\Microsoft\Windows\Application Experience|ProgramDataUpdater|False"], t.Tasks.Calls);
        Assert.Equal((false, "Disabled"), (row.IsOn, row.StatusText));

        // refused: schtasks as TrustedInstaller
        t.Tasks.Refuse.Add("Schedule Scan");
        var scan = list.Rows[@"\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"];
        scan.IsOn = false;
        Assert.Equal([@"schtasks.exe /change /tn ""\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"" /disable"], t.Trusted.Started);
        Assert.Equal(("", false), (scan.Error, scan.IsOn));
    }
}
