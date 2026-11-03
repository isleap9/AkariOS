using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using AkariOS.App.Pages;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using static AkariOS.App.Tests.AppHarness;

namespace AkariOS.App.Tests;

/// <summary>Install AkariOS: the chooser, the Guided steps and the Tweaks step, through AppHarness.</summary>
[Collection("Motion")]
public sealed class InstallPageTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    // the page as the shell shows it: Install AkariOS opened, Guided's Tweaks step
    private AppTest OnTweaks(bool apply = false)
    {
        var t = _h.Make(Fixtures());
        if (apply) Apply(t.S, "fix-plain");
        t.S.Shell.Open("Install AkariOS");
        t.Install.Guide();
        Click(t.Footer.Next);
        return t;
    }

    private static TweakRow Row(AppTest t, string id) => t.Install.Tweaks.Rows[id];

    private static void Tick(TweakRow r)
    {
        var box = (CheckBox)r.Control;
        box.IsChecked = box.IsChecked != true;
        Click(box);
    }

    private static List<string> Steps(AppTest t) =>
        t.Footer.Dots.Children.OfType<StackPanel>().Select(p => $"{((TextBlock)p.Children[^1]).Text}={p.Tag}").ToList();

    [Fact]
    public void The_chooser_then_guided_steps_with_the_stepper() => LookTests.OnSta(() =>
    {
        var t = _h.Make(Fixtures());
        t.S.Shell.Open("Install AkariOS");
        var ui = t.Install.Build("");
        Assert.Equal(("Install AkariOS", Visibility.Visible, Visibility.Collapsed), (t.S.Shell.Heading, t.Footer.Bar.Visibility, t.Footer.Next.Visibility));
        var cards = All<Button>(ui).Where(b => b.Tag is "One-click" or "Guided").ToList();
        Click(cards[0]);
        Assert.Contains("One-click isn't in the native app yet: it comes with N7", t.Asked[^1]);

        Click(cards[1]);
        Assert.Equal(("Apps", "Next"), (t.S.Shell.Heading, t.Footer.Next.Content));
        Assert.Equal(["Apps=Current", "Tweaks=", "Review & Apply="], Steps(t));
        Click(t.Footer.Next);
        Assert.Equal(("Tweaks", "Review (0)", false), (t.S.Shell.Heading, t.Footer.Next.Content, t.Footer.Next.IsEnabled));
        Assert.Equal(["Apps=Done", "Tweaks=Current", "Review & Apply="], Steps(t));

        // Back twice: the chooser; once more: Home
        Click(t.Footer.Back);
        Click(t.Footer.Back);
        Assert.Equal("Choose", t.Install.Mode);
        Click(t.Footer.Back);
        Assert.Equal(("Home", Visibility.Collapsed), (t.S.Shell.Page, t.Footer.Bar.Visibility));
    });

    [Fact]
    public void The_real_tweaks_in_their_sections_and_cards() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        t.S.Shell.Open("Install AkariOS");
        t.Install.Guide();
        Click(t.Footer.Next);
        var ui = (FrameworkElement)t.Install.Build("");
        var texts = Texts(ui);
        var headings = Selection.StepGroups(t.S.Engine.Loaded.Tweaks, t.S.Engine.System).Select(g => g.Header).ToList();
        Assert.Equal(["Optimize", "Customize", "Graphics & Hardware", "Advanced"], headings);
        Assert.All(headings, h => Assert.Contains(h, texts));
        // a row per Guided Tweak, none of Tools or Guided = $false
        var ids = Selection.StepGroups(t.S.Engine.Loaded.Tweaks, t.S.Engine.System).SelectMany(g => g.Categories).SelectMany(c => c.Ids).ToList();
        Assert.Equal(ids.Order(), t.Install.Tweaks.Rows.Keys.Order());
        Assert.DoesNotContain(t.S.Engine.Loaded.Tweaks.Where(x => x.Section == "Tools" || !x.Guided), x => t.Install.Tweaks.Rows.ContainsKey(x.Id));
        // a Choice of up to 4 values that can't be typed is segmented; Win32 Priority Separation can be typed
        Assert.IsType<ComboBox>(Row(t, "win32-priority-separation").Control);
        Assert.True(((ComboBox)Row(t, "win32-priority-separation").Control).IsEditable);
    });

    [Fact]
    public void A_checkbox_picks_a_change_and_show_current_state_starts_rows_on_this_pc() => LookTests.OnSta(() =>
    {
        var t = OnTweaks(apply: true);
        var plain = Row(t, "fix-plain");
        var reboots = Row(t, "fix-reboots");
        Assert.True(((CheckBox)plain.Control).IsChecked);
        Tick(reboots);
        Assert.Equal(("Review (1)", true), (t.Footer.Next.Content, t.Footer.Next.IsEnabled));
        Assert.Equal(new Pending("fix-reboots", "Reboots", TweakMode.Apply, null, false, "Default", "Optimized"), t.Install.Selection["fix-reboots"]);
        // unchecking a row that started checked = Revert; one that started unchecked = no change
        Tick(plain);
        Tick(reboots);
        Assert.Equal(["fix-plain Revert"], t.Install.Selection.Values.Select(p => $"{p.Id} {p.Mode}"));
        // nothing changed on the PC
        Assert.Equal((1u, (object?)null), (Fix(t.S, "Plain"), Fix(t.S, "Reboots")));

        // Show current state off: every row unchecked, the picks gone
        var show = All<CheckBox>(t.Install.Build("")).First(c => c.Content as string == "Show current state");
        show.IsChecked = false;
        Click(show);
        Assert.Equal((false, 0), (((CheckBox)plain.Control).IsChecked, t.Install.Selection.Count));
    });

    [Fact]
    public void A_choice_picks_a_value_and_no_change_takes_it_out() => LookTests.OnSta(() =>
    {
        var t = OnTweaks();
        var pick = (ListBox)Row(t, "fix-pick").Control;
        Assert.Equal(["No change", "One (Recommended)", "Two (Windows default)", "Three"], pick.Items.OfType<ListBoxItem>().Select(i => (string)i.Content));
        pick.SelectedIndex = 2;
        Assert.Equal(new Pending("fix-pick", "Pick", TweakMode.Revert, null, false, "State unknown", "Default"), t.Install.Selection["fix-pick"]);
        pick.SelectedIndex = 1;
        Assert.Equal((TweakMode.Apply, false, "One"), (t.Install.Selection["fix-pick"].Mode, t.Install.Selection["fix-pick"].HasValue, t.Install.Selection["fix-pick"].To));
        // a value riskier than its Tweak asks; Cancel puts the row back
        pick.SelectedIndex = 3;
        Assert.Equal("Pick: 'Three' is marked Advanced. Select it anyway?", t.Asked[^1]);
        Assert.Equal((1, "One"), (pick.SelectedIndex, t.Install.Selection["fix-pick"].To));
        t.Answers.Enqueue("Continue");
        pick.SelectedIndex = 3;
        Assert.Equal((3, true), (t.Install.Selection["fix-pick"].Value, t.Install.Selection["fix-pick"].HasValue));
        pick.SelectedIndex = 0;
        Assert.Empty(t.Install.Selection);
    });

    [Fact]
    public void A_confirm_text_asks_and_clear_selection_resets() => LookTests.OnSta(() =>
    {
        var t = OnTweaks();
        var asking = Row(t, "fix-asking");
        Tick(asking);
        Assert.Equal(["Really change it?"], t.Asked);
        Assert.False(((CheckBox)asking.Control).IsChecked);
        t.Answers.Enqueue("Continue");
        Tick(asking);
        Tick(Row(t, "fix-plain"));
        Assert.Equal(2, t.Install.Selection.Count);
        Click(All<Button>(t.Install.Build("")).First(b => b.Content as string == "Clear selection"));
        Assert.Equal((0, false), (t.Install.Selection.Count, ((CheckBox)asking.Control).IsChecked));
    });

    [Fact]
    public void Quick_select_replaces_the_selection_and_keeps_hidden_tweaks_apart() => LookTests.OnSta(() =>
    {
        var t = OnTweaks();
        Directory.CreateDirectory(Path.Combine(_h.Dir, "presets"));
        File.WriteAllText(Path.Combine(_h.Dir, "presets", "Mine.json"),
            """{ "Name": "Mine", "Description": "Mine", "Tweaks": [ "fix-plain", { "fix-pick": 3 }, "fix-hidden", { "fix-asking": "Default" }, "nothing-here" ] }""");
        Tick(Row(t, "fix-reboots"));
        var menu = new ContextMenu();
        t.Install.Tweaks.FillQuickMenu(menu);
        var items = menu.Items.OfType<MenuItem>().ToList();
        Assert.Equal(["Mine", "Save current as preset…"], items.Select(i => (string)i.Header));
        items[0].RaiseEvent(new RoutedEventArgs(MenuItem.ClickEvent));

        Assert.Equal(["fix-plain Apply False", "fix-pick Apply False", "fix-hidden Apply True"],
            t.Install.Selection.Values.Select(p => $"{p.Id} {p.Mode} {p.Hidden}"));
        Assert.Equal((3, true), (t.Install.Selection["fix-pick"].Value, ((CheckBox)Row(t, "fix-plain").Control).IsChecked));
        Assert.Equal((false, 3), (((CheckBox)Row(t, "fix-reboots").Control).IsChecked, ((ListBox)Row(t, "fix-pick").Control).SelectedIndex));

        // Clear selection drops the hidden one too
        t.Install.Tweaks.Reset();
        Assert.Empty(t.Install.Selection);
    });

    [Fact]
    public void Save_current_as_preset_asks_its_name() => LookTests.OnSta(() =>
    {
        var t = OnTweaks();
        t.Install.Tweaks.SavePreset();
        Assert.Equal("Pick some changes first, then save them as a preset.", t.Asked[^1]);
        Tick(Row(t, "fix-plain"));
        t.Answers.Enqueue("My picks|Save");
        t.Install.Tweaks.SavePreset();
        var saved = t.S.Engine.Presets.Find("My picks");
        Assert.NotNull(saved);
        Assert.Equal(["fix-plain"], saved!.Entries.Select(e => e.Id));
    });

    [Fact]
    public void The_search_filters_rows_cards_and_sections() => LookTests.OnSta(() =>
    {
        var t = OnTweaks();
        t.Install.Build("pick");
        Assert.Equal(Visibility.Visible, Row(t, "fix-pick").Row.Visibility);
        Assert.Equal(Visibility.Collapsed, Row(t, "fix-plain").Row.Visibility);
        t.Install.Build("zzzz");
        var headings = All<TextBlock>(t.Install.Build("zzzz")).Where(x => x.Text == "Optimize");
        Assert.All(headings, h => Assert.Equal(Visibility.Collapsed, h.Visibility));
        t.Install.Build("");
        Assert.Equal(Visibility.Visible, Row(t, "fix-plain").Row.Visibility);
    });
}
