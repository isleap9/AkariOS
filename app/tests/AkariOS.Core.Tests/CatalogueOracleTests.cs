using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native Catalogue against src\UI\Catalogue.ps1 (Oracle/Export-Catalogue.ps1) on the real Tweaks, for two
/// made-up PCs: the same Tweaks listed, the same Sections, headers and Category pages in the same order, the same
/// Tweaks on each page, the same search results in the same order.
/// </summary>
public class CatalogueOracleTests
{
    private static readonly string[] Queries = ["dvr", "Mouse", "game", "e", "power plan", "zzzz-nothing"];

    private static readonly Lazy<JsonElement> PowerShell = new(() =>
        Oracle.Run("Export-Catalogue.ps1", ["-Src", Repo.Src, "-Queries", string.Join(",", Queries)]));

    private static readonly Lazy<IReadOnlyList<Tweak>> Loaded = new(() =>
        new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load().Tweaks);

    public static TheoryData<string> Pcs => ["Win11", "Win10"];

    private static FakeSystem Pc(string name) => name == "Win11"
        ? new FakeSystem { Gpus = [new Gpu("x", "GeForce", "NVIDIA")] }
        : new FakeSystem { Build = 19045, Edition = "Core", Chassis = Chassis.Laptop };

    private static List<string> Ids(JsonElement a) => a.EnumerateArray().Select(e => e.GetString()!).ToList();

    [Theory, MemberData(nameof(Pcs))]
    public void The_same_tweaks(string pc) =>
        Assert.Equal(Ids(PowerShell.Value.GetProperty(pc).GetProperty("Tweaks")), Catalogue.Tweaks(Loaded.Value, Pc(pc)).Select(t => t.Id));

    [Theory, MemberData(nameof(Pcs))]
    public void The_same_sections_and_pages(string pc)
    {
        var ps = PowerShell.Value.GetProperty(pc).GetProperty("Pages").EnumerateArray().Select(s =>
            $"{s.GetProperty("Section").GetString()} | {s.GetProperty("Header").GetString()} | " +
            string.Join(", ", s.GetProperty("Pages").EnumerateArray().Select(p => $"{p.GetProperty("Key").GetString()}={p.GetProperty("Category").GetString()}")));
        var mine = Catalogue.Pages(Catalogue.Tweaks(Loaded.Value, Pc(pc))).Select(s =>
            $"{s.Section} | {s.Header} | {string.Join(", ", s.Pages.Select(p => $"{p.Key}={p.Category}"))}");
        Assert.Equal(ps, mine);
    }

    [Theory, MemberData(nameof(Pcs))]
    public void The_same_tweaks_on_each_page(string pc)
    {
        var list = Catalogue.Tweaks(Loaded.Value, Pc(pc));
        var lists = PowerShell.Value.GetProperty(pc).GetProperty("Lists");
        foreach (var page in lists.EnumerateObject())
            Assert.Equal(Ids(page.Value), Catalogue.List(list, page.Name, "").Select(t => t.Id));
    }

    // PowerShell 5.1's Sort-Object is not stable: inside one page its search hits come in any order. The pages come
    // in the same order; the native app keeps each page's own order (its list's) inside them.
    [Theory, MemberData(nameof(Pcs))]
    public void The_same_search_results_page_by_page(string pc)
    {
        var list = Catalogue.Tweaks(Loaded.Value, Pc(pc));
        var byId = list.ToDictionary(t => t.Id);
        var search = PowerShell.Value.GetProperty(pc).GetProperty("Search");
        foreach (var q in Queries)
        {
            var ps = Ids(search.GetProperty(q)).Select(id => byId[id]).ToList();
            var mine = Catalogue.List(list, "", q);
            Assert.Equal(ps.Select(Page), mine.Select(Page));
            Assert.Equal(ps.Select(t => t.Id).Order(), mine.Select(t => t.Id).Order());
            foreach (var page in mine.GroupBy(Page))
                Assert.Equal(Catalogue.List(list, page.Key, "").Where(page.Contains).Select(t => t.Id), page.Select(t => t.Id));
        }
    }

    private static string Page(Tweak t) => Catalogue.Key(t.Section, t.Category);
}
