using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Look;
using AkariOS.App.Pages;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.App.Tests;

/// <summary>The Catalogue page on the real Tweak files (or fixture ones), through AppHarness.</summary>
[Collection("Motion")]
public sealed class CatalogueViewTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private AppTest Make(ISourceFiles? files = null, bool safeMode = false) => _h.Make(files, safeMode);

    private static MemorySourceFiles Fixtures() => AppHarness.Fixtures();

    private static IEnumerable<T> All<T>(DependencyObject root) where T : DependencyObject => AppHarness.All<T>(root);

    private static List<string> Texts(DependencyObject root) => AppHarness.Texts(root);

    private static void Apply(AppServices s, string id, TweakMode mode = TweakMode.Apply) => AppHarness.Apply(s, id, mode);

    private static void Click(ButtonBase b) => AppHarness.Click(b);

    private static void Flip(CatalogueCard c)
    {
        var sw = (ToggleButton)c.Control;
        sw.IsChecked = sw.IsChecked != true;
        Click(sw);
    }

    private static object? Fix(AppServices s, string name) => AppHarness.Fix(s, name);

    // ---- the page, on the real files

    [Fact]
    public void A_category_page_shows_its_tweaks_with_their_states() => LookTests.OnSta(() =>
    {
        var (s, page) = (Make() is var x ? (x.S, x.Page) : default);
        Apply(s, "gaming-capture-off");
        Apply(s, "disable-game-dvr", TweakMode.Revert);
        var ui = page.Build("Catalogue:Optimize/Gaming", "");
        var list = Catalogue.List(page.Tweaks, "Catalogue:Optimize/Gaming", "");
        Assert.Contains($"{list.Count} tweaks", Texts(ui));
        Assert.Equal(list.Select(t => t.Id), All<Border>(ui).Where(b => b.Tag is string id && list.Any(t => t.Id == id)).Select(b => (string)b.Tag));

        var capture = page.Card(s.Engine.Find("gaming-capture-off")!);
        Assert.Equal((true, "Optimized", true), (((ToggleButton)capture.Control).IsChecked, capture.StateLine.Text, capture.Control.IsEnabled));
        Assert.Contains(All<Border>(capture.Card), b => b.Tag as string == "AkariOS");
        Assert.Contains("gaming-capture-off", Texts(capture.Card));

        var dvr = page.Card(s.Engine.Find("disable-game-dvr")!);
        Assert.Equal((false, "Windows default"), (((ToggleButton)dvr.Control).IsChecked, dvr.StateLine.Text));

        // an Action: its button, no State line; this one has C# still to come: off, and the card says so
        var open = page.Card(s.Engine.Find("gaming-open-game-mode")!);
        Assert.IsType<Button>(open.Control);
        Assert.Equal((Visibility.Collapsed, false), (open.StateLine.Visibility, open.Control.IsEnabled));
        Assert.Contains("Not in the native app yet: the PowerShell app can change it today.", Texts(open.Card));
    });

    [Fact]
    public void A_choice_shows_its_values_and_applies_the_one_picked() => LookTests.OnSta(() =>
    {
        var t = Make();
        t.S.Engine.Registry.SetValue(@"HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl", "Win32PrioritySeparation", 0x28, "DWord");
        t.Page.Build("Catalogue:Advanced/Tuning", "");
        var c = t.Page.Card(t.S.Engine.Find("win32-priority-separation")!);
        var box = (ComboBox)c.Control;
        Assert.Equal(["0x26 short, variable, 3:1 (Recommended)", "0x28 short, fixed", "0x18 long, fixed, 3:1"], box.Items.OfType<ComboBoxItem>().Select(i => (string)i.Content));
        Assert.Equal((1, "Custom value"), (box.SelectedIndex, c.StateLine.Text));
        Assert.Contains(All<Viewbox>(c.Card), v => v.ToolTip as string == "Restart required");

        box.SelectedIndex = 2;
        Assert.Equal((2, "Custom value", 0x18u), (box.SelectedIndex, c.StateLine.Text, t.S.Engine.Registry.GetValue(@"HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl", "Win32PrioritySeparation")));
        box.SelectedIndex = 0;
        Assert.Equal((0, "Optimized"), (box.SelectedIndex, c.StateLine.Text));
        // it needs a restart: the restart bar says so
        Assert.Equal((Visibility.Collapsed, "A restart finishes 1 change."), (t.Bars.Visibility, t.Page.Bars.RestartText.Text));
        t.S.Shell.Open("Catalogue:Advanced/Tuning");
        Assert.Equal((Visibility.Visible, Visibility.Visible, Visibility.Collapsed), (t.Bars.Visibility, t.Page.Bars.RestartPc.Visibility, t.Page.Bars.RestartExplorer.Visibility));
    });

    [Fact]
    public void Risk_badges() => LookTests.OnSta(() =>
    {
        var t = Make();
        t.Page.Build("Catalogue:Optimize/Network", "");
        Assert.Contains(All<Border>(t.Page.Card(t.S.Engine.Find("network-no-throttling")!).Card), b => b.Tag as string == "Caution");
    });

    [Fact]
    public void The_search_heads_each_category_and_says_when_nothing_matches() => LookTests.OnSta(() =>
    {
        var t = Make();
        var ui = t.Page.Build("Home", "dvr");
        var hits = Catalogue.List(t.Page.Tweaks, "", "dvr");
        Assert.NotEmpty(hits);
        Assert.All(hits.Select(h => $"{Catalogue.HeaderOf(h.Section)} › {h.Category}").Distinct(), h => Assert.Contains(h, Texts(ui)));
        Assert.Contains("No tweak matches.", Texts(t.Page.Build("Home", "zzzz-nothing")));
    });

    [Fact]
    public void Refresh_reads_the_states_again_and_cards_are_kept() => LookTests.OnSta(() =>
    {
        var t = Make();
        var ui = t.Page.Build("Catalogue:Optimize/Gaming", "");
        var c = t.Page.Card(t.S.Engine.Find("gaming-capture-off")!);
        Assert.Equal("Windows default", c.StateLine.Text);
        Apply(t.S, "gaming-capture-off");
        Click(All<Button>(ui).First(b => b.Content as string == "Refresh"));
        Assert.Equal("Optimized", c.StateLine.Text);

        t.Page.Build("Catalogue:Optimize/Power", "");
        var again = t.Page.Build("Catalogue:Optimize/Gaming", "");
        Assert.Contains(c.Card, ((Panel)again).Children.OfType<Border>());
    });

    [Fact]
    public void The_services_page_keeps_its_tweaks_while_its_list_waits() => LookTests.OnSta(() =>
    {
        var ui = Make().Page.Build("Catalogue:Advanced/Services", "xbox");
        Assert.Contains(Texts(ui), t => t.StartsWith("The list of services on this PC comes with N6", StringComparison.Ordinal));
        Assert.DoesNotContain("No tweak matches.", Texts(ui));
    });

    [Fact]
    public void Searching_from_any_page_looks_through_the_catalogue() => LookTests.OnSta(() =>
    {
        var t = Make();
        var pages = PageFactory.For(t.S);
        t.S.Shell.Search = "dvr";
        Assert.Contains(Texts(pages("Home")), x => x.EndsWith("› Gaming", StringComparison.Ordinal));
        Assert.DoesNotContain(Texts(pages("Downloads")), x => x.EndsWith("› Gaming", StringComparison.Ordinal));
    });

    // ---- changes, on fixture Tweaks

    [Fact]
    public void A_switch_applies_and_reverts_right_away_after_one_restore_point() => LookTests.OnSta(() =>
    {
        var t = Make(Fixtures());
        t.S.Shell.Open("Catalogue:Optimize/Test");
        t.Page.Build("Catalogue:Optimize/Test", "");
        var c = t.Page.Card(t.S.Engine.Find("fix-plain")!);
        Assert.Equal("Windows default", c.StateLine.Text);
        Flip(c);
        Assert.Equal((1u, "Optimized", true), (Fix(t.S, "Plain"), c.StateLine.Text, ((ToggleButton)c.Control).IsChecked));
        Flip(c);
        Assert.Equal((null, "Windows default"), (Fix(t.S, "Plain"), c.StateLine.Text));
        // the session's first change made the restore point; nothing asked
        Assert.Equal(["AkariOS"], t.Restore.Points.Select(p => p.Description));
        Assert.Empty(t.Asked);
        Assert.Equal(("Ready", false), (t.S.Shell.StatusText, t.Page.Running));

        // Explorer = $true: the restart bar offers Explorer's restart, which clears it
        Assert.Equal(("Explorer needs a restart to show 1 change.", Visibility.Visible), (t.Page.Bars.RestartText.Text, t.Bars.Visibility));
        Click(t.Page.Bars.RestartExplorer);
        Assert.Equal((1, Visibility.Collapsed), (t.Explorer.Restarts, t.Bars.Visibility));
    });

    [Fact]
    public void An_akarios_restore_point_from_before_asks_and_skip_means_none_this_session() => LookTests.OnSta(() =>
    {
        var t = Make(Fixtures());
        t.Restore.Points.Add(new("AkariOS", new DateTime(2026, 10, 1, 9, 30, 0), 7));
        t.Page.Build("Catalogue:Optimize/Test", "");
        t.Answers.Enqueue("Skip");
        Flip(t.Page.Card(t.S.Engine.Find("fix-plain")!));
        Flip(t.Page.Card(t.S.Engine.Find("fix-reboots")!));
        Assert.Single(t.Asked);
        Assert.StartsWith("AkariOS already made a restore point on ", t.Asked[0]);
        Assert.Single(t.Restore.Points);
        Assert.Equal(1u, Fix(t.S, "Reboots"));
    });

    [Fact]
    public void A_confirm_text_asks_first_and_cancel_changes_nothing() => LookTests.OnSta(() =>
    {
        var t = Make(Fixtures());
        t.Page.Build("Catalogue:Optimize/Test", "");
        var c = t.Page.Card(t.S.Engine.Find("fix-asking")!);
        Flip(c);
        Assert.Equal(["Really change it?"], t.Asked);
        Assert.Equal((null, false), (Fix(t.S, "Asking"), ((ToggleButton)c.Control).IsChecked));
        t.Answers.Enqueue("Continue");
        Flip(c);
        Assert.Equal(1u, Fix(t.S, "Asking"));
        // going back to the Windows default never asks
        Flip(c);
        Assert.Equal((2, (object?)null), (t.Asked.Count, Fix(t.S, "Asking")));

        // a Choice value riskier than its Tweak asks; its Default doesn't
        var pick = (ComboBox)t.Page.Card(t.S.Engine.Find("fix-pick")!).Control;
        pick.SelectedIndex = 2;
        Assert.Equal("Pick: 'Three' is marked Advanced. Select it anyway?", t.Asked[^1]);
        Assert.Null(Fix(t.S, "Pick"));
        pick.SelectedIndex = 1;
        Assert.Equal((3, 2u), (t.Asked.Count, Fix(t.S, "Pick")));
    });

    [Fact]
    public void A_safe_mode_tweak_waits_in_its_bar_and_closing_asks() => LookTests.OnSta(() =>
    {
        var t = Make(Fixtures());
        t.S.Shell.Open("Catalogue:Optimize/Test");
        t.Page.Build("Catalogue:Optimize/Test", "");
        var c = t.Page.Card(t.S.Engine.Find("fix-safe")!);
        Flip(c);
        Assert.Equal((null, "Waiting for Safe Mode", true), (Fix(t.S, "Safe"), c.StateLine.Text, ((ToggleButton)c.Control).IsChecked));
        Assert.Equal((Visibility.Visible, "1 change needs Safe Mode: Akari restarts into it, applies them and restarts back."), (t.Page.Bars.SafeBar.Visibility, t.Page.Bars.SafeText.Text));
        // off Catalogue pages the bars go
        t.S.Shell.Open("Home");
        Assert.Equal(Visibility.Collapsed, t.Bars.Visibility);

        // closing: "Restart and apply" keeps the window open (N7 runs it); Discard closes
        t.Answers.Enqueue("Restart and apply");
        var e = new CancelEventArgs();
        t.Page.OnClosing(null, e);
        Assert.True(e.Cancel);
        Assert.StartsWith("1 change is waiting for Safe Mode.", t.Asked[0]);
        Assert.Contains("comes with N7", t.Asked[1]);
        t.Answers.Enqueue("Discard");
        e = new CancelEventArgs();
        t.Page.OnClosing(null, e);
        Assert.False(e.Cancel);

        // switched back before the restart: nothing waits
        Flip(c);
        Assert.Empty(t.Page.SafePending);
        Assert.Equal("Windows default", c.StateLine.Text);
    });

    [Fact]
    public void In_safe_mode_a_safe_mode_tweak_runs_now() => LookTests.OnSta(() =>
    {
        var t = Make(Fixtures(), safeMode: true);
        t.Page.Build("Catalogue:Optimize/Test", "");
        Flip(t.Page.Card(t.S.Engine.Find("fix-safe")!));
        Assert.Equal(1u, Fix(t.S, "Safe"));
        Assert.Empty(t.Page.SafePending);
    });

    [Fact]
    public void Restart_now_asks_then_restarts_the_pc() => LookTests.OnSta(() =>
    {
        var t = Make(Fixtures());
        t.S.Shell.Open("Catalogue:Optimize/Test");
        t.Page.Build("Catalogue:Optimize/Test", "");
        Flip(t.Page.Card(t.S.Engine.Find("fix-reboots")!));
        Assert.Equal(Visibility.Visible, t.Page.Bars.RestartPc.Visibility);
        Click(t.Page.Bars.RestartPc);
        Assert.Equal(0, t.Shutdown.Restarts);
        t.Answers.Enqueue("Restart now");
        Click(t.Page.Bars.RestartPc);
        Assert.Equal((1, "Restart the PC now? Save your work first."), (t.Shutdown.Restarts, t.Asked[^1]));
    });

    [Fact]
    public void Changes_queue_one_at_a_time() => LookTests.OnSta(() =>
    {
        var t = Make(Fixtures());
        // the background holds its work until the test lets it go
        var held = new Queue<Action>();
        var s = new AppServices
        {
            Engine = t.S.Engine, Shell = t.S.Shell, Open = t.S.Open, Log = t.S.Log, Theme = t.S.Theme, Bars = t.Bars,
            Background = (work, done) => held.Enqueue(() => done(work())),
            Dialogs = t.S.Dialogs,
        };
        var page = new CatalogueView(s);
        page.Build("Catalogue:Optimize/Test", "");
        while (held.TryDequeue(out var a)) a();
        var (plain, reboots) = (page.Card(s.Engine.Find("fix-plain")!), page.Card(s.Engine.Find("fix-reboots")!));
        Flip(plain);
        Flip(reboots);
        Assert.Equal(("Applying…", "Waiting…", false), (plain.StateLine.Text, reboots.StateLine.Text, reboots.Control.IsEnabled));
        Assert.Equal(("Plain: apply", true), (s.Shell.StatusText, s.Shell.Busy));
        Assert.Single(held);
        held.Dequeue()();
        Assert.Equal(("Optimized", "Applying…"), (plain.StateLine.Text, reboots.StateLine.Text));
        held.Dequeue()();
        Assert.Equal(("Optimized", "Ready"), (reboots.StateLine.Text, s.Shell.StatusText));
        Assert.Equal((1u, 1u), (Fix(s, "Plain"), Fix(s, "Reboots")));
    });
}
