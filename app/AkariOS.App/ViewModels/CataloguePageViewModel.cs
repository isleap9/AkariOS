using AkariOS.Core.Tweaks;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.ViewModels;
using AkariOS.App.Shell;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>What a Catalogue page shows: a Section (<c>Catalogue:Optimize</c>: its Categories), a Category's own page
/// (<c>Catalogue:Optimize/Gaming</c>: its cards), or, with a query, the search's results.
/// Flash: a search suggestion's Tweak id, its card scrolled to and flashed (Open-AkariSuggestion).</summary>
public sealed record CatalogueQuery(string Key, string Query = "", string Flash = "");

/// <summary>A Category's row on a drill-down Section's page (Windows 11 Settings' look): its name, glyph, a line
/// saying what is inside, how many Tweaks; it opens the Category's own page.</summary>
public sealed record CategoryLink(string Key, string Name, string Glyph, int Count, string Description = "")
{
    public string CountText => $"{Count} tweak{(Count == 1 ? "" : "s")}";
}

/// <summary>A group of Category rows (Desktop, Behaviour; "" = a Section's only group, no heading).</summary>
public sealed record CategoryGroup(string Title, IReadOnlyList<CategoryLink> Links)
{
    public bool HasTitle => Title.Length > 0;
}

/// <summary>A Category on a Catalogue page: its heading and cards (search results: "Section › Category"); the Services
/// and Scheduled tasks pages list what is on the PC under their Tweaks.</summary>
public sealed record CatalogueGroup(string Key, string Title, IReadOnlyList<TweakCardViewModel> Cards,
    ServicesListViewModel? Services = null, TasksListViewModel? Tasks = null, StartupListViewModel? Startup = null)
{
    public bool HasServices => Services is not null;
    public bool HasTasks => Tasks is not null;
    public bool HasStartup => Startup is not null;
}

/// <summary>
/// A Catalogue page, a drill-down (Windows 11 Settings' pattern, where the PowerShell app's Show-AkariCataloguePage
/// is one long page whose SelectorBar scrolls): a Section's page lists its Categories as rows in groups
/// (<see cref="CategoryInfo"/>), each Category has its own page with its cards (Optimize › Section › Category); the
/// search's results (Show-AkariSearchResults) list every match by Category. The cards and every change are the one
/// <see cref="CatalogueViewModel"/>'s.
/// </summary>
public sealed partial class CataloguePageViewModel(CatalogueViewModel catalogue, ServicesListViewModel services, TasksListViewModel tasks, IShellNavigator navigator,
    StartupListViewModel? startup = null) : ViewModelBase, INavigationAware
{
    public static readonly string ServicesKey = Core.Tweaks.Catalogue.Key("Advanced", "Services");
    public static readonly string TasksKey = Core.Tweaks.Catalogue.Key("Advanced", "Scheduled tasks");
    public static readonly string StartupKey = Core.Tweaks.Catalogue.Key("Tools", "Startup");

    public CatalogueViewModel Catalogue => catalogue;

    /// <summary>A Section's own page: its Categories (no cards), in their groups' order.</summary>
    public IReadOnlyList<CategoryLink> Categories { get; private set; } = [];

    /// <summary>The same Categories in their groups (CategoryInfo).</summary>
    public IReadOnlyList<CategoryGroup> CategoryGroups { get; private set; } = [];

    public bool IsDrill => Categories.Count > 0;

    private string _sectionKey = "";

    /// <summary>A Category card clicked: its own page.</summary>
    public void OpenCategory(string key) => navigator.Open(key);

    public string Subtitle { get; private set; } = "";

    public bool IsSearch { get; private set; }

    public IReadOnlyList<CatalogueGroup> Groups { get; private set; } = [];

    /// <summary>A suggestion's Tweak: its card is scrolled to and flashed ("" = none).</summary>
    public string Flash { get; private set; } = "";

    /// <summary>The title as a breadcrumb (Set-AkariHeader): Optimize › the Section (› the Category on a Category's
    /// page); none on the results.</summary>
    public IReadOnlyList<string> Crumbs { get; private set; } = [];

    public bool HasCrumbs => Crumbs.Count > 0;
    public bool HasNoCrumbs => Crumbs.Count == 0;

    /// <summary>The line above the heading: every crumb but the last (the heading itself), each a link.</summary>
    public IReadOnlyList<CrumbLink> CrumbLinks => [.. Crumbs.Take(Math.Max(0, Crumbs.Count - 1)).Select((c, i) => new CrumbLink(c, () => OpenCrumb(i)))];

    /// <summary>A crumb clicked: the first is Optimize's overview, the second (on a Category's page) its Section.</summary>
    public void OpenCrumb(int index)
    {
        if (index >= Crumbs.Count - 1) return;
        if (index == 0) navigator.Open("Optimize");
        else if (index == 1) navigator.Open(_sectionKey);
    }

    public string CountText { get; private set; } = "";

    public string EmptyText => Groups.Count > 0 || IsDrill ? "" : IsSearch ? "No tweak matches." : "Nothing here yet.";

    public bool IsEmpty => Groups.Count == 0 && !IsDrill;

    /// <summary>The count and Refresh: not on a Section's list of Categories.</summary>
    public bool HasCards => !IsDrill;

    public void OnNavigatedTo(object? parameter)
    {
        if (parameter is not CatalogueQuery q) return;
        Show(q);
    }

    public void OnNavigatedFrom() { }

    /// <summary>Builds the page and reads its States.</summary>
    public void Show(CatalogueQuery q)
    {
        var tweaks = catalogue.Tweaks;
        IsSearch = q.Query.Trim().Length > 0;
        Categories = [];
        CategoryGroups = [];
        if (IsSearch)
        {
            var found = Core.Tweaks.Catalogue.List(tweaks, "", q.Query.Trim());
            Title = $"Results for “{q.Query.Trim()}”";
            Subtitle = "Every section of Optimize";
            Crumbs = [];
            Groups = found.GroupBy(t => Core.Tweaks.Catalogue.Key(t.Section, t.Category))
                .Select(g => new CatalogueGroup(g.Key, $"{Core.Tweaks.Catalogue.HeaderOf(g.First().Section)} › {g.First().Category}",
                    g.Select(catalogue.Card).ToList()))
                .ToList();
        }
        else
        {
            var split = Core.Tweaks.Catalogue.Split(q.Key);
            var sectionName = split?.Section ?? q.Key[Core.Tweaks.Catalogue.Prefix.Length..];
            var section = catalogue.Sections.FirstOrDefault(s => s.Section == sectionName);
            var header = Core.Tweaks.Catalogue.HeaderOf(sectionName);
            _sectionKey = Core.Tweaks.Catalogue.Prefix + sectionName;
            Subtitle = "Each change applies right away.";
            var pages = section?.Pages ?? [];
            if (split is null)
            {
                // the Section's own page: its Categories
                Title = header;
                Subtitle = "Pick a category. Each change applies right away.";
                Crumbs = ["Optimize", header];
                Categories = [.. pages.Select(p =>
                    {
                        var list = Core.Tweaks.Catalogue.List(tweaks, p.Key, "");
                        var note = CategoryInfo.Of(sectionName, p.Category);
                        return new CategoryLink(p.Key, p.Category, CategoryGlyphs.Of(p.Category), list.Count,
                            note?.Description ?? CategoryInfo.FromNames([.. list.Select(t => t.Name)]));
                    })
                    .OrderBy(c => CategoryInfo.Order(sectionName, c.Name))];
                CategoryGroups = [.. Categories.GroupBy(c => CategoryInfo.Of(sectionName, c.Name)?.Group ?? CategoryInfo.More)
                    .Select(g => new CategoryGroup(g.Key, [.. g]))];
                pages = [];
            }
            else
            {
                // a Category's own page
                Title = split.Value.Category;
                Crumbs = ["Optimize", header, Title];
                pages = [.. pages.Where(p => p.Key == q.Key)];
            }
            Groups = pages.Select(p => new CatalogueGroup(p.Key, p.Category,
                Core.Tweaks.Catalogue.List(tweaks, p.Key, "").Select(catalogue.Card).ToList(),
                p.Key == ServicesKey ? services : null, p.Key == TasksKey ? tasks : null, p.Key == StartupKey ? startup : null)).ToList();
            if (Groups.Any(g => g.HasServices)) services.Show();
            if (Groups.Any(g => g.HasTasks)) tasks.Show();
            if (Groups.Any(g => g.HasStartup)) startup?.Show();
        }
        Flash = q.Flash;
        catalogue.Highlight(Groups.SelectMany(g => g.Cards), IsSearch ? q.Query : "");
        var n = Groups.Sum(g => g.Cards.Count);
        CountText = $"{n} tweak{(n == 1 ? "" : "s")}";
        OnPropertyChanged(string.Empty);
        Refresh();
    }

    /// <summary>Reads the page's States again.</summary>
    [RelayCommand]
    public void Refresh() => catalogue.ReadStates(Groups.SelectMany(g => g.Cards).Select(c => c.Tweak));
}
