using AkariOS.App.Shell;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.ViewModels;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>A Section's card on Optimize's overview: its header, glyph, first four Categories, how many Tweaks.</summary>
public sealed record OptimizeSection(string Key, string Header, string Glyph, string Categories, int Count)
{
    public string CountText => Count.ToString(System.Globalization.CultureInfo.CurrentCulture);
}

/// <summary>
/// Optimize's overview (Show-AkariOptimize): the Catalogue's Sections as cards (each opens its page), then a few Tools
/// as the Catalogue's own cards ($AkariOptimizeTools: a restore point, the temp files, this PC's graphics driver). The
/// PowerShell page's Legacy expander is not here: the native app never reads Legacy (ADR 0004, AGENTS.md).
/// </summary>
public sealed partial class OptimizeViewModel(CatalogueViewModel catalogue, IShellNavigator navigator) : ViewModelBase, INavigationAware
{
    /// <summary>$AkariOptimizeTools: the first three this PC has are shown.</summary>
    public static IReadOnlyList<string> ToolIds { get; } = ["oneclick-restore-point", "cleanup-temp-files", "tools-driver-nvidia", "tools-driver-amd", "tools-driver-intel"];

    public const string Lead = "Every Tweak, by section. Each change applies the moment you flip it, and you can switch it back the same way.";

    public IReadOnlyList<OptimizeSection> Sections { get; } = [.. catalogue.Sections.Select(s =>
    {
        var cats = s.Pages.Select(p => p.Category).ToList();
        var text = string.Join(", ", cats.Take(4)) + (cats.Count > 4 ? "…" : "");
        return new OptimizeSection(Core.Tweaks.Catalogue.Prefix + s.Section, s.Header, NavTable.SectionGlyph(s.Section), text,
            catalogue.Tweaks.Count(t => t.Section == s.Section));
    })];

    public IReadOnlyList<TweakCardViewModel> Tools { get; } = [.. ToolIds
        .Select(id => catalogue.Tweaks.FirstOrDefault(t => t.Id == id)).OfType<Core.Tweaks.Tweak>().Take(3).Select(catalogue.Card)];

    public bool HasTools => Tools.Count > 0;

    public void OnNavigatedTo(object? parameter)
    {
        catalogue.Highlight([], "");
        catalogue.ReadStates(Tools.Select(c => c.Tweak));
    }

    public void OnNavigatedFrom() { }

    [RelayCommand]
    public void Open(string key) => navigator.Open(key);
}
