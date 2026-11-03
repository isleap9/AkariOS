using System.IO;
using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Tests;

public class ShellLayoutTests
{
    [Theory]
    [InlineData("Home", "Home")]
    [InlineData("Install AkariOS", "Install AkariOS")]
    [InlineData("Optimize", "Optimize")]
    [InlineData("Catalogue:Optimize/Gaming", "Optimize")]
    [InlineData("Remove apps", "Optimize")]
    [InlineData("Downloads", "Downloads")]
    [InlineData("ISO Builder", "ISO Builder")]
    [InlineData("About", "")]
    public void Every_page_has_its_tab(string page, string tab) => Assert.Equal(tab, ShellLayout.TabOf(page));

    [Theory]
    [InlineData("Catalogue:Customize/Taskbar", "Search Optimize")]
    [InlineData("Downloads", "Search apps")]
    [InlineData("Remove apps", "Search apps")]
    [InlineData("Install AkariOS", "Filter this step")]
    [InlineData("Catalogue:Advanced/Services", "Search services")]
    [InlineData("Catalogue:Advanced/Scheduled tasks", "Search tasks")]
    public void The_search_says_what_it_looks_through(string page, string hint) => Assert.Equal(hint, ShellLayout.SearchHint(page));

    [Theory]
    [InlineData(1600, true, false, false, true, 5)]
    [InlineData(1440, true, false, false, true, 5)]
    [InlineData(1360, false, false, false, true, 5)]
    [InlineData(1319, false, false, true, true, 3)]
    [InlineData(999, false, true, true, false, 2)]
    public void Widths(double width, bool icons, bool shortLabels, bool narrow, bool wordmark, int columns)
    {
        Assert.Equal((icons, shortLabels), ShellLayout.TabLayout(width));
        Assert.Equal(narrow, ShellLayout.Narrow(width));
        Assert.Equal(wordmark, ShellLayout.Wordmark(width));
        Assert.Equal(columns, ShellLayout.HomeColumns(width));
    }

    [Fact]
    public void Short_labels_in_a_narrow_window()
    {
        Assert.Equal(["Home", "Install", "Optimize", "Downloads", "Unattend", "ISO"], ShellLayout.Tabs.Select(t => ShellLayout.TabLabel(t.Name, 900)));
        Assert.Equal("Install AkariOS", ShellLayout.TabLabel("Install AkariOS", 1200));
    }

    [Theory]
    [InlineData("Applying", 0, 0, null, "Applying")]
    [InlineData("Applying", 0, 5, "Game DVR", "Applying (1 of 5): Game DVR")]
    [InlineData("Applying", 5, 5, "", "Applying (5 of 5)")]
    public void Progress_text(string label, int done, int total, string? step, string text) =>
        Assert.Equal(text, ShellLayout.ProgressText(label, done, total, step));

    [Theory]
    [InlineData("Catalogue:Hardware/Graphics", "", "Graphics", "Graphics & Hardware. Each change applies right away.", "monitor")]
    [InlineData("Catalogue:Optimize/Odd one", "", "Odd one", "Optimize. Each change applies right away.", "settings")]
    [InlineData("Catalogue:Optimize/Gaming", "dvr", "Search", "Results for \"dvr\" in Optimize › Advanced", "search")]
    [InlineData("Catalogue:Advanced/Services", "xbox", "Services", "Advanced. Each change applies right away.", "activity")]
    [InlineData("Downloads", "", "Downloads", "Install apps, runtimes and tools, from winget where possible", "download")]
    [InlineData("Home", "dvr", "Search", "Results for \"dvr\"", "search")]
    public void Page_headers(string page, string query, string heading, string sub, string glyph) =>
        Assert.Equal((heading, sub, glyph), ShellLayout.Header(page, query));

    // the map is a copy of src/UI/Cards.ps1's (a code file, not data): read that one's text and compare
    [Fact]
    public void The_category_icons_are_Cards_ps1s()
    {
        var text = File.ReadAllText(Path.Combine(LookTests.RepoRoot(), "src", "UI", "Cards.ps1"));
        var start = text.IndexOf("$AkariCategoryGlyphs = @{", StringComparison.Ordinal);
        var end = text.IndexOf("\n}", start, StringComparison.Ordinal);
        var map = (PsHashtable)PsData.ParseValue(text[(start + "$AkariCategoryGlyphs = ".Length)..(end + 2)])!;
        Assert.Equal(map.OrderBy(k => k.Key).Select(k => $"{k.Key}={k.Value}"), Icons.Categories.OrderBy(k => k.Key).Select(k => $"{k.Key}={k.Value}"));
    }

    [Fact]
    public void Every_icon_the_shell_names_is_in_Icons_xaml()
    {
        var icons = AkariXaml.Text("Icons.xaml");
        var names = ShellLayout.Tabs.Select(t => t.Icon).Concat(ShellLayout.Pages.Values.Select(p => p.Glyph)).Concat(Icons.Categories.Values)
            .Concat(["search", "menu", "minus", "square", "copy", "x", "wrench", "settings", "trash-2"]);
        Assert.All(names, n => Assert.Contains($"x:Key=\"Ic.{n}\"", icons));
    }

    [Fact]
    public void Every_page_says_when_it_comes() =>
        Assert.All(ShellLayout.Pages.Keys, p => Assert.NotEqual("a later milestone", Placeholder.Milestone(p)));
}

public class ShellViewModelTests
{
    [Fact]
    public void Home_has_no_header_and_the_other_pages_do()
    {
        var vm = new ShellViewModel("1.3.0");
        Assert.Equal(("Home", "Home", false), (vm.Page, vm.Tab, vm.HeaderVisible));
        Assert.Equal("AkariOS 1.3.0", vm.Version);
        vm.Open("Downloads");
        Assert.Equal(("Downloads", "download", true, "Search apps"), (vm.Heading, vm.Glyph, vm.HeaderVisible, vm.SearchHint));
        vm.Open("About");
        Assert.Equal("", vm.Tab);
    }

    [Fact]
    public void The_optimize_tab_goes_back_to_the_optimize_page_seen_last()
    {
        var vm = new ShellViewModel("1");
        vm.Open("Catalogue:Optimize/Gaming");
        Assert.Equal(("Gaming", "Optimize"), (vm.Heading, vm.Tab));
        vm.Open("Home");
        vm.Open("Optimize");
        Assert.Equal("Catalogue:Optimize/Gaming", vm.Page);
    }

    internal static readonly IReadOnlyList<CatalogueSection> Optimize =
    [
        new("Optimize", "Optimize", [new("Catalogue:Optimize/Gaming", "Gaming"), new("Catalogue:Optimize/Power", "Power")]),
        new("Hardware", "Graphics & Hardware", [new("Catalogue:Hardware/Graphics", "Graphics")]),
    ];

    [Fact]
    public void The_optimize_tab_opens_the_catalogues_first_page_and_remove_apps_is_not_remembered()
    {
        var vm = new ShellViewModel("1", Optimize);
        Assert.Equal("", vm.Section);
        vm.Open("Optimize");
        Assert.Equal(("Catalogue:Optimize/Gaming", "Optimize", "Gaming"), (vm.Page, vm.Section, vm.Heading));
        vm.Open("Catalogue:Hardware/Graphics");
        Assert.Equal("Hardware", vm.Section);
        vm.Open("Remove apps");
        Assert.Equal(("Optimize", ""), (vm.Tab, vm.Section));
        vm.Open("Optimize");
        Assert.Equal("Catalogue:Hardware/Graphics", vm.Page);
    }

    [Fact]
    public void A_page_moves_on_a_new_page_or_the_search_starting_and_ending()
    {
        var vm = new ShellViewModel("1");
        var moves = 0;
        vm.PageMoved += () => moves++;
        vm.Search = "d";
        vm.Search = "dv";
        vm.Search = "dvr";
        Assert.Equal(1, moves);
        Assert.Equal(("Search", "Results for \"dvr\"", true), (vm.Heading, vm.Sub, vm.HeaderVisible));
        vm.Search = "";
        Assert.Equal(2, moves);
        vm.Search = "x";
        vm.Open("Downloads");
        Assert.Equal(("", 4), (vm.Search, moves));
    }

    [Fact]
    public void The_status_bar()
    {
        var vm = new ShellViewModel("1");
        vm.SetProgress(1, 2, "x");
        Assert.Equal(("Ready", (double?)null), (vm.StatusText, vm.Progress));
        vm.SetBusy(true);
        Assert.Equal(("Working…", true, true), (vm.StatusText, vm.Busy, vm.Locked));
        vm.SetBusy(true, "Applying", locked: false);
        vm.SetProgress(1, 4, "Game DVR");
        Assert.Equal(("Applying (2 of 4): Game DVR", 0.25, false), (vm.StatusText, vm.Progress, vm.Locked));
        vm.SetBusy(false);
        Assert.Equal(("Ready", false, (double?)null), (vm.StatusText, vm.Busy, vm.Progress));
    }
}

[Collection("Motion")]
public sealed class MainWindowTests
{
    [Fact]
    public void The_window_builds_and_its_tabs_follow_the_page() => LookTests.OnSta(() =>
    {
        Motion.Initialize(false);
        var resources = AkariXaml.SharedResources("Dark", false).ToList();
        var fonts = new ResourceDictionary();
        Assets.AddFonts(fonts);
        resources.Add(fonts);
        var host = new ResourceDictionary();
        foreach (var d in resources) host.MergedDictionaries.Add(d);
        var theme = new ThemeService(host, new SettingsFile(Path.Combine(Path.GetTempPath(), $"akari-shell-{Guid.NewGuid():N}.json")), () => null, false);
        var vm = new ShellViewModel("1.3.0");
        var shown = new List<string>();
        var window = new MainWindow(theme, vm, p => { shown.Add(p); return new TextBlock { Text = p }; }, resources);

        var tabs = window.Tabs.Children.OfType<RadioButton>().ToList();
        Assert.Equal(ShellLayout.Tabs.Select(t => t.Name), tabs.Select(t => (string)t.Tag));
        Assert.True(tabs[0].IsChecked);
        Assert.Equal(["Home"], shown);

        tabs[3].IsChecked = true;
        Assert.Equal("Downloads", vm.Page);
        Assert.Equal("Downloads", ((TextBlock)window.Page.Content).Text);

        vm.Open("Catalogue:Optimize/Gaming");
        Assert.True(tabs[2].IsChecked);
        Assert.False(tabs[3].IsChecked);
        vm.Open("About");
        Assert.DoesNotContain(tabs, t => t.IsChecked == true);
        Assert.Equal(["Home", "Downloads", "Catalogue:Optimize/Gaming", "About"], shown);

        vm.SetBusy(true, "Applying");
        Assert.Equal((Visibility.Visible, Visibility.Collapsed, false), (window.StatusRing.Visibility, window.StatusDot.Visibility, window.Page.IsEnabled));
        window.Close();
    });

    [Fact]
    public void Optimizes_sub_header_follows_the_catalogue_page() => LookTests.OnSta(() =>
    {
        var (window, vm) = Make(new ShellViewModel("1", ShellViewModelTests.Optimize));
        Assert.Equal(Visibility.Collapsed, window.SubNav.Visibility);
        Assert.Equal(["Optimize", "Graphics & Hardware"], window.Sections.Items.OfType<ListBoxItem>().Select(i => (string)i.Content));

        vm.Open("Optimize");
        Assert.Equal(Visibility.Visible, window.SubNav.Visibility);
        var chips = window.Chips.Children.OfType<RadioButton>().ToList();
        Assert.Equal(["Catalogue:Optimize/Gaming", "Catalogue:Optimize/Power"], chips.Select(c => (string)c.Tag));
        Assert.Equal([true, false], chips.Select(c => c.IsChecked == true));

        chips[1].IsChecked = true;
        Assert.Equal("Catalogue:Optimize/Power", vm.Page);
        // a Section opens its first page, and its chips replace the others
        window.Sections.SelectedIndex = 1;
        Assert.Equal("Catalogue:Hardware/Graphics", vm.Page);
        Assert.Equal(["Catalogue:Hardware/Graphics"], window.Chips.Children.OfType<RadioButton>().Select(c => (string)c.Tag));

        window.RemoveApps.RaiseEvent(new RoutedEventArgs(System.Windows.Controls.Primitives.ButtonBase.ClickEvent));
        Assert.Equal(("Remove apps", Visibility.Collapsed), (vm.Page, window.SubNav.Visibility));
        window.Close();
    });

    private static (MainWindow, ShellViewModel) Make(ShellViewModel vm)
    {
        Motion.Initialize(false);
        var resources = AkariXaml.SharedResources("Dark", false).ToList();
        var host = new ResourceDictionary();
        foreach (var d in resources) host.MergedDictionaries.Add(d);
        var theme = new ThemeService(host, new SettingsFile(Path.Combine(Path.GetTempPath(), $"akari-shell-{Guid.NewGuid():N}.json")), () => null, false);
        return (new MainWindow(theme, vm, p => new TextBlock { Text = p }, resources), vm);
    }
}
