using AkariOS.Core.Tweaks;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.ViewModels;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>What a Catalogue page shows: a Section (<c>Catalogue:Optimize</c>), a Category in it
/// (<c>Catalogue:Optimize/Gaming</c>: the Section scrolled to it), or, with a query, the search's results.</summary>
public sealed record CatalogueQuery(string Key, string Query = "");

/// <summary>A Category on a Catalogue page: its heading and cards (search results: "Section › Category"); the Services
/// and Scheduled tasks pages list what is on the PC under their Tweaks.</summary>
public sealed record CatalogueGroup(string Key, string Title, IReadOnlyList<TweakCardViewModel> Cards,
    ServicesListViewModel? Services = null, TasksListViewModel? Tasks = null)
{
    public bool HasServices => Services is not null;
    public bool HasTasks => Tasks is not null;
}

/// <summary>
/// A Catalogue page (Show-AkariCataloguePage, Show-AkariSearchResults): its heading, its Categories (the SelectorBar)
/// with their cards, the Category to scroll to, Refresh. The cards and every change are the one
/// <see cref="CatalogueViewModel"/>'s.
/// </summary>
public sealed partial class CataloguePageViewModel(CatalogueViewModel catalogue, ServicesListViewModel services, TasksListViewModel tasks) : ViewModelBase, INavigationAware
{
    public static readonly string ServicesKey = Core.Tweaks.Catalogue.Key("Advanced", "Services");
    public static readonly string TasksKey = Core.Tweaks.Catalogue.Key("Advanced", "Scheduled tasks");

    public CatalogueViewModel Catalogue => catalogue;

    public string Subtitle { get; private set; } = "";

    public bool IsSearch { get; private set; }

    public IReadOnlyList<CatalogueGroup> Groups { get; private set; } = [];

    /// <summary>The Category to show first (a Category page), or "".</summary>
    public string ScrollTo { get; private set; } = "";

    public string CountText { get; private set; } = "";

    public string EmptyText => Groups.Count > 0 ? "" : IsSearch ? "No tweak matches." : "Nothing here yet.";

    public bool IsEmpty => Groups.Count == 0;

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
        if (IsSearch)
        {
            var found = Core.Tweaks.Catalogue.List(tweaks, "", q.Query.Trim());
            Title = $"Results for “{q.Query.Trim()}”";
            Subtitle = "Every section of Optimize";
            ScrollTo = "";
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
            Title = Core.Tweaks.Catalogue.HeaderOf(sectionName);
            Subtitle = "Each change applies right away.";
            ScrollTo = split is null ? "" : q.Key;
            Groups = (section?.Pages ?? []).Select(p => new CatalogueGroup(p.Key, p.Category,
                Core.Tweaks.Catalogue.List(tweaks, p.Key, "").Select(catalogue.Card).ToList(),
                p.Key == ServicesKey ? services : null, p.Key == TasksKey ? tasks : null)).ToList();
            if (Groups.Any(g => g.HasServices)) services.Show();
            if (Groups.Any(g => g.HasTasks)) tasks.Show();
        }
        var n = Groups.Sum(g => g.Cards.Count);
        CountText = $"{n} tweak{(n == 1 ? "" : "s")}";
        OnPropertyChanged(string.Empty);
        Refresh();
    }

    /// <summary>Reads the page's States again.</summary>
    [RelayCommand]
    public void Refresh() => catalogue.ReadStates(Groups.SelectMany(g => g.Cards).Select(c => c.Tweak));
}
