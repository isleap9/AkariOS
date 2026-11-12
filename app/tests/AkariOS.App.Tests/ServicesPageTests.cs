using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Pages;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using static AkariOS.App.Tests.AppHarness;

namespace AkariOS.App.Tests;

/// <summary>The Services and Scheduled tasks pages (src/UI/ServicesPage.ps1, TasksPage.ps1) on the real Tweak files,
/// the PC's services and tasks faked; changes through the Catalogue's queue, the restore point first.</summary>
[Collection("Motion")]
public sealed class ServicesPageTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private static readonly string ServicesPage = Catalogue.Key("Advanced", "Services");
    private static readonly string TasksPage = Catalogue.Key("Advanced", "Scheduled tasks");

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
            t.S.Engine.Registry.SetValue($@"{ServiceStart.Root}\{n}", "Start", 2, "DWord");
        t.Tasks.List.AddRange([
            new TaskInfo(@"\Microsoft\Windows\UpdateOrchestrator\", "Schedule Scan", true, "Ready", "Scans for updates", "Microsoft"),
            new TaskInfo(@"\Microsoft\Windows\Application Experience\", "ProgramDataUpdater", true, "Ready", "Telemetry", "Microsoft"),
            new TaskInfo(@"\", "ContosoUpdate", true, "Ready", "An app's updater", "Contoso"),
        ]);
        return t;
    }

    private static UIElement Open(AppTest t, string page, string query = "")
    {
        t.S.Shell.Open(page);
        return t.Page.Build(page, query);
    }

    // the list's rows on the page, in order (row cards are tagged with their key; the Tweak cards and badges have
    // tags of their own)
    private static List<string> Shown(UIElement ui, AppTest t)
    {
        var keys = t.Page.Services.Rows.Keys.Concat(t.Page.Tasks.Rows.Keys).ToHashSet();
        return All<Border>(ui).Select(b => b.Tag).OfType<string>().Where(keys.Contains).ToList();
    }

    [Fact]
    public void The_services_page_lists_what_fr33thy_and_zoicware_change_and_show_all_lists_every_one() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Open(t, ServicesPage);
        Assert.Contains("Turn off most Windows services", Texts(ui));
        Assert.Equal(["BITS", "Spooler"], Shown(ui, t));
        Assert.Contains("2 services FR33THY and ZOICWARE change", Texts(ui));
        Assert.Equal(1, t.Services.Reads);
        t.Page.Services.ShowAll = true;
        Assert.Equal(["BITS", "Contoso", "Spooler", "RpcSs"], Shown(ui, t));
        Assert.Contains("4 services", Texts(ui));
        t.Page.Services.Filter = "Running";
        Assert.Equal(["BITS", "RpcSs"], Shown(ui, t));
        Assert.Contains("2 of 4 services", Texts(ui));
        // the search filters the list; the page's Tweaks stay
        t.Page.Services.Filter = "All";
        ui = t.Page.Build(ServicesPage, "print");
        Assert.Equal(["Spooler"], Shown(ui, t));
        Assert.Contains("Turn off most Windows services", Texts(ui));
        Assert.Equal(1, t.Services.Reads);
    });

    [Fact]
    public void A_startup_type_is_written_to_the_service_key_after_the_restore_point() => LookTests.OnSta(() =>
    {
        var t = Pc();
        Open(t, ServicesPage);
        var row = t.Page.Services.Rows["BITS"];
        row.Combo.SelectedItem = row.Combo.Items.OfType<ComboBoxItem>().First(i => i.Tag as string == "Disabled");
        Assert.Equal(4u, t.S.Engine.Registry.GetValue($@"{ServiceStart.Root}\BITS", "Start"));
        Assert.Equal(0u, t.S.Engine.Registry.GetValue($@"{ServiceStart.Root}\BITS", "DelayedAutostart"));
        Assert.Single(t.Restore.Points);
        Assert.Equal("", row.Error);
        Assert.Contains("Background Intelligent Transfer Service: startup type Disabled", ((Core.MemoryLog)t.S.Log).Lines);
    });

    [Fact]
    public void Start_and_stop_act_on_the_service_and_read_it_back() => LookTests.OnSta(() =>
    {
        var t = Pc();
        Open(t, ServicesPage);
        var row = t.Page.Services.Rows["BITS"];
        Assert.Equal("Stop", row.Button.Content);
        Click(row.Button);
        Assert.Equal(["Stop BITS"], t.Services.Calls);
        Assert.Equal("Start", row.Button.Content);
        Assert.Contains("Stopped", Texts(row.Card));
    });

    [Fact]
    public void Disabling_a_service_windows_needs_asks_first() => LookTests.OnSta(() =>
    {
        var t = Pc();
        Open(t, ServicesPage);
        t.Page.Services.ShowAll = true;
        var row = t.Page.Services.Rows["RpcSs"];
        row.Combo.SelectedItem = row.Combo.Items.OfType<ComboBoxItem>().First(i => i.Tag as string == "Disabled");
        Assert.Single(t.Asked);
        Assert.Contains("is a service Windows needs", t.Asked[0]);
        Assert.Equal(2u, t.S.Engine.Registry.GetValue($@"{ServiceStart.Root}\RpcSs", "Start"));
        Assert.Equal("Automatic", (row.Combo.SelectedItem as ComboBoxItem)?.Tag);
    });

    [Fact]
    public void A_change_that_fails_says_why_on_its_row() => LookTests.OnSta(() =>
    {
        var t = Pc();
        t.S.Engine.Registry.DeleteKey($@"{ServiceStart.Root}\Spooler");
        Open(t, ServicesPage);
        var row = t.Page.Services.Rows["Spooler"];
        row.Combo.SelectedItem = row.Combo.Items.OfType<ComboBoxItem>().First(i => i.Tag as string == "Manual");
        Assert.Equal("no service named Spooler", row.Error);
        Assert.Contains("Failed: no service named Spooler", Texts(row.Card));
    });

    [Fact]
    public void The_tasks_page_lists_what_fr33thy_and_zoicware_turn_off_and_switches_them() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Open(t, TasksPage);
        Assert.Contains("Remove all scheduled tasks", Texts(ui));
        var shown = Shown(ui, t);
        Assert.Contains(@"\Microsoft\Windows\UpdateOrchestrator\Schedule Scan", shown);
        Assert.DoesNotContain(@"\ContosoUpdate", shown);
        t.Page.Tasks.ShowAll = true;
        Assert.Contains(@"\ContosoUpdate", Shown(ui, t));

        // as admin
        var row = t.Page.Tasks.Rows[@"\Microsoft\Windows\Application Experience\ProgramDataUpdater"];
        row.Switch.IsChecked = false;
        Click(row.Switch);
        Assert.Equal([@"\Microsoft\Windows\Application Experience|ProgramDataUpdater|False"], t.Tasks.Calls);
        Assert.Equal(false, row.Switch.IsChecked);
        Assert.Contains("Disabled", Texts(row.Card));

        // refused: schtasks as TrustedInstaller
        t.Tasks.Refuse.Add("Schedule Scan");
        var scan = t.Page.Tasks.Rows[@"\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"];
        scan.Switch.IsChecked = false;
        Click(scan.Switch);
        Assert.Equal([@"schtasks.exe /change /tn ""\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"" /disable"], t.Trusted.Started);
        Assert.Equal(("", false), (scan.Error, scan.Switch.IsChecked));
    });
}
