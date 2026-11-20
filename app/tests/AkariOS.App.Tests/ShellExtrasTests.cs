using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.Framework.Services;

namespace AkariOS.App.Tests;

/// <summary>
/// The PowerShell app's shell parts brought over last: Optimize's overview (Show-AkariOptimize), the titles as
/// breadcrumbs (Set-AkariHeader, Open-AkariCrumb), a suggestion's card flashed (Open-AkariSuggestion), the match marked in
/// the results (Set-AkariCardHighlight), the first run's search tip (Show-AkariSearchTip).
/// </summary>
public sealed class ShellExtrasTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    [Fact]
    public void Optimize_opens_its_overview()
    {
        Assert.Equal(new NavRoute(NavPage.Optimize, "Optimize", "Optimize", ""), NavTable.Route("Optimize"));
    }

    [Fact]
    public void The_overview_lists_the_Sections_and_a_few_Tools()
    {
        var t = _h.Make();
        var o = t.Optimize();
        Assert.Equal(t.Catalogue.Sections.Select(s => s.Header), o.Sections.Select(s => s.Header));
        var first = o.Sections[0];
        var section = t.Catalogue.Sections[0];
        Assert.Equal("Catalogue:" + section.Section, first.Key);
        Assert.Equal(t.Catalogue.Tweaks.Count(x => x.Section == section.Section), first.Count);
        var cats = section.Pages.Select(p => p.Category).ToList();
        Assert.Equal(string.Join(", ", cats.Take(4)) + (cats.Count > 4 ? "…" : ""), first.Categories);
        Assert.Equal(NavTable.SectionGlyph(section.Section), first.Glyph);

        // $AkariOptimizeTools this PC has (no GPU here: no driver Tool), at most three, in that order
        Assert.InRange(o.Tools.Count, 1, 3);
        var ids = o.Tools.Select(c => c.Id).ToList();
        Assert.Equal(OptimizeViewModel.ToolIds.Where(ids.Contains), ids);
        Assert.DoesNotContain(ids, id => id.StartsWith("tools-driver-", StringComparison.Ordinal));

        o.Open(first.Key);
        Assert.Equal([first.Key], t.Navigated);
    }

    [Fact]
    public void A_Section_page_titles_itself_Optimize_then_the_Section_and_the_first_crumb_opens_the_overview()
    {
        var t = _h.Make(AppHarness.Fixtures());
        var p = t.Page("Catalogue:Optimize");
        Assert.Equal(["Optimize", "Optimize"], p.Crumbs);
        Assert.True(p.HasCrumbs);
        p.OpenCrumb(1);
        Assert.Empty(t.Navigated);
        p.OpenCrumb(0);
        Assert.Equal(["Optimize"], t.Navigated);

        var results = t.Page("", "plain");
        Assert.Empty(results.Crumbs);
        Assert.True(results.HasNoCrumbs);
    }

    [Fact]
    public void Customize_lists_its_Categories_and_each_Category_has_its_own_page()
    {
        var t = _h.Make(AppHarness.Fixtures());
        var header = Core.Tweaks.Catalogue.HeaderOf("Customize");

        // the Section's page: its Categories, no cards
        var s = t.Page("Catalogue:Customize");
        Assert.True(s.IsDrill);
        // a Category CategoryInfo doesn't know: the More group, its line from its Tweaks' names
        Assert.Equal([new CategoryLink("Catalogue:Customize/Look", "Look", CategoryGlyphs.Of("Look"), 1, "Dark")], s.Categories);
        Assert.Equal([CategoryInfo.More], s.CategoryGroups.Select(g => g.Title));
        Assert.Equal(["Optimize"], s.CrumbLinks.Select(c => c.Text));
        s.CrumbLinks[0].OpenCommand.Execute(null);
        Assert.Equal(["Optimize"], t.Navigated);
        t.Navigated.Clear();
        Assert.Equal("1 tweak", s.Categories[0].CountText);
        Assert.Empty(s.Groups);
        Assert.False(s.IsEmpty);
        Assert.False(s.HasCards);
        Assert.Equal(["Optimize", header], s.Crumbs);
        s.OpenCategory("Catalogue:Customize/Look");
        Assert.Equal(["Catalogue:Customize/Look"], t.Navigated);

        // a Category's page: only its cards, Optimize › Customize › Look
        var c = t.Page("Catalogue:Customize/Look");
        Assert.False(c.IsDrill);
        Assert.True(c.HasCards);
        Assert.Equal(["Look"], c.Groups.Select(g => g.Title));
        Assert.Equal(["fix-dark"], c.Groups[0].Cards.Select(x => x.Id));
        Assert.Equal("Look", c.Title);
        Assert.Equal(["Optimize", header, "Look"], c.Crumbs);
        Assert.Equal(["Optimize", header], c.CrumbLinks.Select(x => x.Text));
        c.OpenCrumb(2);
        c.OpenCrumb(1);
        c.OpenCrumb(0);
        Assert.Equal(["Catalogue:Customize/Look", "Catalogue:Customize", "Optimize"], t.Navigated);

        // a suggestion lands on the Category's page with its card to flash
        var p = new CataloguePageViewModel(t.Catalogue, t.ServiceList, t.TaskList, new NoNav());
        p.OnNavigatedTo(new CatalogueQuery("Catalogue:Customize/Look", "", "fix-dark"));
        Assert.Equal("fix-dark", p.Flash);
    }

    [Fact]
    public void Customize_groups_its_Categories_in_Desktop_and_Behaviour()
    {
        var t = _h.Make();
        var s = t.Page("Catalogue:Customize");
        Assert.Equal(["Desktop", "Behaviour"], s.CategoryGroups.Select(g => g.Title));
        // in CategoryInfo's order: Taskbar first
        Assert.Equal(CategoryInfo.All.Where(x => x.Section == "Customize").Select(x => x.Category).Where(n => s.Categories.Any(c => c.Name == n)),
            s.Categories.Select(c => c.Name));
        Assert.Equal("Taskbar", s.Categories[0].Name);
        Assert.All(s.Categories, c => Assert.True(c.Count > 0));
    }

    [Fact]
    public void A_line_from_Tweak_names_takes_the_first_three()
    {
        Assert.Equal("A, B", CategoryInfo.FromNames(["A", "B"]));
        Assert.Equal("A, B, C, …", CategoryInfo.FromNames(["A", "B", "C", "D"]));
    }

    [Fact]
    public void Every_real_Category_of_every_Section_has_its_line()
    {
        var t = _h.Make();
        foreach (var section in t.Catalogue.Sections)
        {
            var s = t.Page("Catalogue:" + section.Section);
            Assert.True(s.IsDrill);
            Assert.DoesNotContain(CategoryInfo.More, s.CategoryGroups.Select(g => g.Title));
            Assert.All(s.Categories, c => Assert.Equal(CategoryInfo.Of(section.Section, c.Name)!.Description, c.Description));
        }
        // Graphics & Hardware: one group, no heading
        Assert.Equal([""], t.Page("Catalogue:Hardware").CategoryGroups.Select(g => g.Title));
        Assert.False(t.Page("Catalogue:Hardware").CategoryGroups[0].HasTitle);
    }

    [Fact]
    public void Results_mark_the_match_and_every_other_page_shows_names_plain()
    {
        var t = _h.Make(AppHarness.Fixtures());
        var card = t.Card("fix-plain");
        t.Page("", "LAI");
        Assert.Equal([new TextPart("P", false), new TextPart("lai", true), new TextPart("n", false)], card.NameText.Parts);
        // the same card on its Section page: plain
        t.Page("Catalogue:Optimize");
        Assert.Equal([new TextPart("Plain", false)], card.NameText.Parts);
        t.Page("", "lai");
        t.Optimize();
        Assert.Equal("", card.Query);
    }

    [Fact]
    public void Split_cuts_a_name_around_every_match_ignoring_case()
    {
        Assert.Equal([new TextPart("Game ", false), new TextPart("DVR", true), new TextPart(" off, ", false), new TextPart("dvr", true)],
            TextMatch.Split("Game DVR off, dvr", "dvr"));
        Assert.Equal([new TextPart("a.b", false)], TextMatch.Split("a.b", " "));
        Assert.Equal([new TextPart("a", false), new TextPart(".", true), new TextPart("b", false)], TextMatch.Split("a.b", "."));
    }

    [Fact]
    public void A_suggestion_opens_its_Category_with_its_card_to_flash()
    {
        var t = _h.Make(AppHarness.Fixtures());
        var p = new CataloguePageViewModel(t.Catalogue, t.ServiceList, t.TaskList, new NoNav());
        p.OnNavigatedTo(new CatalogueQuery("Catalogue:Optimize/Test", "", "fix-plain"));
        Assert.Equal("fix-plain", p.Flash);
        Assert.Contains(p.Groups.Single().Cards, c => c.Id == "fix-plain");
        p.OnNavigatedTo(new CatalogueQuery("Catalogue:Optimize"));
        Assert.Equal("", p.Flash);
    }

    private sealed class NoNav : IShellNavigator
    {
        public void Open(string key) { }
    }

    [Fact]
    public async Task Guided_titles_itself_Install_AkariOS_then_the_step_and_the_first_crumb_goes_back_to_the_chooser()
    {
        var t = _h.Make(AppHarness.Fixtures());
        var i = t.Install;
        Assert.Empty(i.Crumbs);
        i.Guide();
        Assert.Equal(["Install AkariOS", "Apps"], i.Crumbs);
        await i.NextAsync();
        Assert.Equal(["Install AkariOS", "Tweaks"], i.Crumbs);
        i.Selection["fix-plain"] = new Core.Tweaks.Pending("fix-plain", "Plain", Core.Tweaks.TweakMode.Apply, null, false, "Default", "Optimized");
        i.OpenCrumb(0);
        Assert.True(i.IsChoosing);
        Assert.Empty(i.Crumbs);
        // the picks are kept
        Assert.Single(i.Selection);
    }

    private sealed class Settings : ISettingsService
    {
        public Dictionary<string, object?> Values { get; } = [];
        public Task<T?> GetAsync<T>(string key, T? defaultValue = default) => Task.FromResult(Values.TryGetValue(key, out var v) ? (T?)v : defaultValue);
        public Task SetAsync<T>(string key, T value) { Values[key] = value; return Task.CompletedTask; }
        public Task RemoveAsync(string key) { Values.Remove(key); return Task.CompletedTask; }
    }

    [Fact]
    public async Task The_search_tip_shows_until_it_was_seen()
    {
        var settings = new Settings();
        var tip = new SearchTip(settings);
        Assert.True(await tip.ShouldShowAsync());
        await tip.SeenAsync();
        Assert.False(await tip.ShouldShowAsync());
        Assert.Equal("Seen", settings.Values[SearchTip.Key]);
        Assert.Equal("380 Tweaks across Optimize, Customize, Hardware, Advanced and Tools. Press Ctrl+F from anywhere.", SearchTip.Text(380));
    }
}
