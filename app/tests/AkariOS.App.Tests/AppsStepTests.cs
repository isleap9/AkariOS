using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Pages;
using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;
using static AkariOS.App.Tests.AppHarness;

namespace AkariOS.App.Tests;

/// <summary>The Apps step (src/UI/Apps.ps1) and its flows (Guided's first step, Downloads, Remove apps) on the real
/// Tweak files, the PC's packages and features faked.</summary>
[Collection("Motion")]
public sealed class AppsStepTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    // a PC with Clipchamp (Recommended), Paint (Keep), Teams (Caution) and an app the data file doesn't list
    private AppTest Pc()
    {
        var t = _h.Make();
        t.Packages.Add("Clipchamp.Clipchamp", "Microsoft.Paint", "MSTeams", "Contoso.Unknown", "Microsoft.WindowsStore");
        t.Dism.Capabilities.AddRange([new DismItem("Browser.InternetExplorer~~~~0.0.11.0", "Installed"), new DismItem("Microsoft.Windows.Notepad~~~~0.0.1.0", "Installed"),
            new DismItem("App.StepsRecorder~~~~0.0.1.0", "NotPresent")]);
        t.Dism.Features.AddRange([new DismItem("Printing-XPSServices-Features", "Enabled"), new DismItem("NetFx3", "Enabled"), new DismItem("Printing-Foo", "Disabled")]);
        return t;
    }

    private static UIElement Guided(AppTest t)
    {
        t.S.Shell.Open("Install AkariOS");
        t.Install.Guide();
        return t.Install.Build("");
    }

    private static AppsStep Apps(AppTest t) => t.Install.Apps;

    private static Button Button(UIElement ui, string text) => All<Button>(ui).First(b => b.Content as string == text);

    private static void Tick(AppTest t, string id)
    {
        var box = Apps(t).Rows[id].Box;
        box.IsChecked = box.IsChecked != true;
        Click(box);
    }

    private static List<string> Picked(AppTest t) => t.Install.Selection.Keys.Order(StringComparer.Ordinal).ToList();

    private static bool Shown(AppTest t, string id) => Apps(t).Rows[id].Row.Visibility == Visibility.Visible;

    [Fact]
    public void The_remove_tab_lists_the_store_apps_features_and_legacy_apps() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Guided(t);
        var rows = Apps(t).Rows;
        Assert.True(rows.ContainsKey("appx/Clipchamp.Clipchamp"));
        Assert.True(rows.ContainsKey("appx/Contoso.Unknown"));
        Assert.True(rows.ContainsKey("remove-onedrive"));
        // the features were read once the Remove tab showed: only what is on the PC
        Assert.True(rows.ContainsKey("capability/Browser.InternetExplorer~~~~0.0.11.0"));
        Assert.False(rows.ContainsKey("capability/App.StepsRecorder~~~~0.0.1.0"));
        Assert.True(rows.ContainsKey("feature/NetFx3"));
        Assert.False(rows.ContainsKey("feature/Printing-Foo"));
        // Only installed (on by default): a data file app that isn't here is hidden
        Assert.True(Shown(t, "appx/Clipchamp.Clipchamp"));
        Assert.False(Shown(t, "appx/Microsoft.BingNews"));
        var texts = Texts(ui);
        Assert.Contains("Store apps (", string.Join("|", texts));
        Assert.Contains("Optional features (2)", texts);
        Assert.Contains("Windows features (2)", texts);
        Assert.Contains("0 to remove, 0 to install", texts);
    });

    [Fact]
    public void A_checked_app_is_a_pending_removal_and_review_lists_it() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Guided(t);
        Tick(t, "appx/Clipchamp.Clipchamp");
        Tick(t, "install-steam");
        Assert.Equal(["appx/Clipchamp.Clipchamp", "install-steam"], Picked(t));
        Assert.Equal("Remove", t.Install.Selection["appx/Clipchamp.Clipchamp"].To);
        Assert.Contains("1 to remove, 1 to install", Texts(ui));
        Tick(t, "install-steam");
        Assert.Equal(["appx/Clipchamp.Clipchamp"], Picked(t));
        // Next, Next: Review lists the removal
        Click(t.Footer.Next);
        Click(t.Footer.Next);
        Assert.Contains("Clipchamp", Texts(t.Install.Build("")));
    });

    [Fact]
    public void A_not_recommended_removal_asks_first() => LookTests.OnSta(() =>
    {
        var t = Pc();
        Guided(t);
        var advanced = Apps(t).Rows.Values.First(r => r.Tweak.Risk == Risk.Advanced && r.Installed);
        advanced.Box.IsChecked = true;
        Click(advanced.Box);
        Assert.Single(t.Asked);
        Assert.Empty(t.Install.Selection);
        Assert.False(advanced.Box.IsChecked);
    });

    [Fact]
    public void Select_recommended_akarios_and_clear() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Guided(t);
        Click(Button(ui, "Select recommended"));
        var recommended = Picked(t);
        Assert.Contains("appx/Clipchamp.Clipchamp", recommended);
        Assert.DoesNotContain("appx/Microsoft.Paint", recommended);
        Assert.DoesNotContain("appx/Microsoft.BingNews", recommended);
        Assert.All(recommended, id => Assert.Equal(Risk.Safe, Apps(t).Rows[id].Tweak.Risk));

        Click(Button(ui, "AkariOS"));
        var akarios = Picked(t);
        Assert.Contains("appx/MSTeams", akarios);
        Assert.Contains("appx/Contoso.Unknown", akarios);
        Assert.Contains("capability/Browser.InternetExplorer~~~~0.0.11.0", akarios);
        Assert.Contains("feature/Printing-XPSServices-Features", akarios);
        // the keep-list stays: Paint, Notepad, .NET 3.5
        Assert.DoesNotContain("appx/Microsoft.Paint", akarios);
        Assert.DoesNotContain("capability/Microsoft.Windows.Notepad~~~~0.0.1.0", akarios);
        Assert.DoesNotContain("feature/NetFx3", akarios);

        Click(Button(ui, "Clear selection"));
        Assert.Empty(t.Install.Selection);
    });

    [Fact]
    public void Downloads_shows_the_install_cards_alone_and_never_reads_the_features() => LookTests.OnSta(() =>
    {
        var t = Pc();
        t.S.Shell.Open("Downloads");
        var ui = t.Install.Build("");
        Assert.Equal(("Downloads", "Install"), (t.S.Shell.Heading, Apps(t).Tab));
        Assert.Equal(0, t.Dism.Reads);
        Assert.Equal(Visibility.Visible, t.Footer.Bar.Visibility);
        Assert.Equal(("Review (0)", false), (t.Footer.Next.Content, t.Footer.Next.IsEnabled));
        Assert.False(AncestorsVisible(Button(ui, "Select recommended")));
        // the restore card: the Store is here, the new Snipping Tool isn't
        Assert.False(Apps(t).Rows.ContainsKey("install-microsoft-store"));
        Assert.True(Apps(t).Rows.ContainsKey("store/Microsoft.ScreenSketch"));
        Tick(t, "install-steam");
        Assert.Equal(("Review (1)", true), (t.Footer.Next.Content, t.Footer.Next.IsEnabled));
        Click(t.Footer.Next);
        Assert.Equal("Review & Install", t.S.Shell.Heading);
        // Back twice: the cards, then where Downloads was opened (Home)
        Click(t.Footer.Back);
        Click(t.Footer.Back);
        Assert.Equal("Home", t.S.Shell.Page);
    });

    // ---- winutil W4: Downloads' own toolbar (Update all apps, Uninstall selected, Show installed)

    private static UIElement Downloads(AppTest t)
    {
        t.S.Shell.Open("Downloads");
        return t.Install.Build("");
    }

    private const string UninstallFlags = "--exact --source winget --silent --accept-source-agreements --disable-interactivity";

    [Fact]
    public void Downloads_has_its_own_three_buttons_and_guided_has_not() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var guided = Guided(t);
        Click(Button(guided, "Install"));
        foreach (var b in new[] { "Update all apps", "Uninstall selected", "Show installed" }) Assert.False(AncestorsVisible(Button(guided, b)));
        var ui = Downloads(t);
        foreach (var b in new[] { "Update all apps", "Uninstall selected", "Show installed" }) Assert.True(AncestorsVisible(Button(ui, b)));
        Assert.False(Button(ui, "Uninstall selected").IsEnabled);
        Tick(t, "install-steam");
        Assert.True(Button(ui, "Uninstall selected").IsEnabled);
        Tick(t, "install-steam");
        Assert.False(Button(ui, "Uninstall selected").IsEnabled);
    });

    [Fact]
    public void Uninstall_selected_asks_with_the_names_then_uninstalls_the_checked_apps() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Downloads(t);
        foreach (var id in new[] { "install-steam", "install-vcredist", "install-microsoft-edge", "install-custom-resolution-utility" }) Tick(t, id);
        // Esc: nothing runs
        Click(Button(ui, "Uninstall selected"));
        var asked = t.Asked[^1];
        Assert.StartsWith("Uninstall these apps?\n\n- ", asked);
        Assert.Contains("- Steam", asked);
        Assert.Contains("\n\nOther apps may need these runtimes.\n\nNot uninstalled here:\n", asked);
        Assert.Contains("- Microsoft Edge: use Remove apps", asked);
        Assert.Contains("- Custom Resolution Utility: use Windows' Installed apps", asked);
        Assert.Empty(t.Winget.Calls);
        Assert.Equal(0, t.Install.Step);

        t.Answers.Enqueue("Uninstall");
        Click(Button(ui, "Uninstall selected"));
        Assert.Contains($"uninstall --id Valve.Steam {UninstallFlags}", t.Winget.Calls);
        Assert.DoesNotContain(t.Winget.Calls, c => c.Contains("Microsoft.Edge", StringComparison.Ordinal));
        Assert.Equal((3, true, false), (t.Install.Step, t.Install.Uninstalled, t.Install.Running));
        Assert.Equal(["Reverted", "Reverted", "Skipped", "Skipped"], t.Install.Outcomes.Select(o => o.Kind.ToString()).Order());
        Assert.Empty(t.Restore.Points);
        var result = Texts(t.Install.Build(""));
        Assert.Contains("2 uninstalled, 2 skipped", result);
        Assert.Contains("Uninstalled", result);
        Assert.Contains("Skipped: has its own removal: use Remove apps", result);
        // Done: back where Downloads was opened, the next result in the usual words again
        Click(t.Footer.Next);
        Assert.Equal(("Home", false), (t.S.Shell.Page, t.Install.Uninstalled));
    });

    [Fact]
    public void Uninstall_selected_only_says_so_when_nothing_picked_can_be_uninstalled_here() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Downloads(t);
        Tick(t, "install-microsoft-edge");
        Click(Button(ui, "Uninstall selected"));
        Assert.Equal("None of these apps can be uninstalled here:\n- Microsoft Edge: use Remove apps", t.Asked[^1]);
        Assert.Equal((0, false), (t.Install.Step, t.Install.Running));
        Assert.Empty(t.Winget.Calls);
    });

    [Fact]
    public void Show_installed_marks_the_apps_on_this_pc_and_reads_again_for_a_new_page() => LookTests.OnSta(() =>
    {
        var t = Pc();
        t.Winget.Answer = a => a[0] == "list" ? new(0, ["Name   Id            Version", "Steam  Valve.Steam   2.10"]) : null;
        var ui = Downloads(t);
        Assert.Equal(Visibility.Collapsed, Apps(t).Rows["install-steam"].Mark!.Visibility);
        Assert.Empty(t.Winget.Calls);
        Click(Button(ui, "Show installed"));
        Assert.Equal(["list --accept-source-agreements --disable-interactivity"], t.Winget.Calls);
        Assert.Equal(Visibility.Visible, Apps(t).Rows["install-steam"].Mark!.Visibility);
        Assert.Equal(Visibility.Collapsed, Apps(t).Rows["install-discord"].Mark!.Visibility);
        Assert.False(t.S.Shell.Busy);
        // a removal row has no such mark
        Assert.Null(Apps(t).Rows.Values.First(r => r.Removal).Mark);

        // after a run the page is built anew: its marks are read again by themselves
        Tick(t, "install-steam");
        t.Answers.Enqueue("Uninstall");
        Click(Button(ui, "Uninstall selected"));
        Click(t.Footer.Next);
        Downloads(t);
        Assert.Equal(Visibility.Visible, Apps(t).Rows["install-steam"].Mark!.Visibility);
        Assert.Equal(2, t.Winget.Calls.Count(c => c.StartsWith("list ", StringComparison.Ordinal)));
    });

    [Fact]
    public void Update_all_apps_asks_with_the_tweaks_own_question_then_runs_it_alone() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var ui = Downloads(t);
        Tick(t, "install-steam");
        Click(Button(ui, "Update all apps"));
        Assert.Equal(t.S.Engine.Find("tools-update-apps")!.Confirm, t.Asked[^1]);
        Assert.Equal(0, t.Install.Step);
        t.Answers.Enqueue("Update all");
        Click(Button(ui, "Update all apps"));
        // the Tools Tweak alone (not the picked install), no restore point, the result in the usual words
        Assert.Equal(["tools-update-apps"], t.Install.Outcomes.Select(o => o.Id));
        Assert.Equal((3, false), (t.Install.Step, t.Install.Uninstalled));
        Assert.Empty(t.Restore.Points);
        Assert.DoesNotContain(t.Winget.Calls, c => c.StartsWith("install ", StringComparison.Ordinal));
    });

    private static bool AncestorsVisible(FrameworkElement e)
    {
        for (DependencyObject? p = e; p is not null; p = LogicalTreeHelperParent(p))
            if (p is UIElement u && u.Visibility != Visibility.Visible) return false;
        return true;
    }

    private static DependencyObject? LogicalTreeHelperParent(DependencyObject d) => LogicalTreeHelper.GetParent(d);

    [Fact]
    public void Remove_apps_from_a_catalogue_page_shows_the_remove_tables_and_goes_back_there() => LookTests.OnSta(() =>
    {
        var t = Pc();
        var page = Catalogue.Key("Optimize", "Privacy");
        t.S.Shell.Open(page);
        t.S.Shell.Open("Remove apps");
        var ui = t.Install.Build("");
        Assert.Equal(("Remove apps", "Remove"), (t.S.Shell.Heading, Apps(t).Tab));
        Assert.False(AncestorsVisible(Apps(t).Rows["install-steam"].Row));
        Assert.True(AncestorsVisible(Apps(t).Rows["appx/Clipchamp.Clipchamp"].Row));
        Assert.False(AncestorsVisible(All<Button>(ui).First(b => b.Content as string == "Quick select ▾")));
        Click(t.Footer.Back);
        Assert.Equal(page, t.S.Shell.Page);
    });

    [Fact]
    public void Switching_flows_starts_afresh() => LookTests.OnSta(() =>
    {
        var t = Pc();
        t.S.Shell.Open("Downloads");
        t.Install.Build("");
        Tick(t, "install-steam");
        t.S.Shell.Open("Remove apps");
        t.Install.Build("");
        Assert.Empty(t.Install.Selection);
        t.S.Shell.Open("Install AkariOS");
        t.Install.Build("");
        Assert.Equal("Choose", t.Install.Mode);
    });

    [Fact]
    public void The_search_and_only_installed_filter_the_rows() => LookTests.OnSta(() =>
    {
        var t = Pc();
        Guided(t);
        t.Install.Build("clip");
        Assert.True(Shown(t, "appx/Clipchamp.Clipchamp"));
        Assert.False(Shown(t, "appx/MSTeams"));
        t.Install.Build("");
        Apps(t).OnlyInstalled = false;
        Assert.True(Shown(t, "appx/Microsoft.BingNews"));
    });

    [Fact]
    public void Quick_select_akarios_picks_the_apps_on_this_pc_but_the_keep_list() => LookTests.OnSta(() =>
    {
        var t = Pc();
        Guided(t);
        var akarios = t.Install.Tweaks.Presets().First(p => p.Builtin && p.Name == "AkariOS");
        t.Install.Tweaks.QuickSelect(akarios);
        var picked = Picked(t);
        Assert.Contains("appx/Clipchamp.Clipchamp", picked);
        Assert.Contains("appx/Contoso.Unknown", picked);
        Assert.Contains("feature/Printing-XPSServices-Features", picked);
        Assert.DoesNotContain("appx/Microsoft.Paint", picked);
        Assert.DoesNotContain("appx/Microsoft.BingNews", picked);
        // the Tweaks too
        Assert.Contains(picked, id => !id.Contains('/', StringComparison.Ordinal) && !id.StartsWith("remove-", StringComparison.Ordinal));
        Assert.True(Apps(t).Rows["appx/Clipchamp.Clipchamp"].Box.IsChecked);
    });

    [Fact]
    public void Home_counts_the_removable_apps_but_the_keep_list() => LookTests.OnSta(() =>
    {
        var t = Pc();
        Assert.Equal(4, HomePage.RemovableApps(t.S));
    });
}
