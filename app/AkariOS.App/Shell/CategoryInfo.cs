using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.Shell;

/// <summary>A Category's row on its Section's page (Windows 11 Settings' look): its group ("" = the Section's only
/// one, no heading) and a line saying what is inside.</summary>
public sealed record CategoryNote(string Group, string Description);

/// <summary>
/// The lines under each Category on a Section's page, and the groups they sit in, per Section (presentation only, like
/// <see cref="CategoryGlyphs"/>; the Categories themselves come from the loaded Tweaks), read from the shared
/// src/UI/Categories.psd1 (the PowerShell app's CataloguePage.ps1 reads it too). A Category missing there goes in the
/// last group, <see cref="More"/>, its line made from its first Tweaks' names (<see cref="FromNames"/>).
/// </summary>
public static class CategoryInfo
{
    public const string More = "More";

    public const string File = "src/UI/Categories.psd1";

    /// <summary>Every Section's Categories, in the order they show on its page.</summary>
    public static IReadOnlyList<(string Section, string Category, CategoryNote Note)> All { get; } = Read(new EmbeddedSourceFiles());

    /// <summary>The rows of <see cref="File"/>: <c>Categories = @(@{ Section; Category; Group; Line })</c>.</summary>
    public static IReadOnlyList<(string Section, string Category, CategoryNote Note)> Read(ISourceFiles files)
    {
        var h = (PsHashtable)PsData.Parse(files.ReadText(File)).Value!;
        static string S(PsHashtable t, string k) => PsSemantics.Text(t.Get(k)) ?? "";
        return [.. PsSemantics.AsList(h.Get("Categories")).OfType<PsHashtable>()
            .Select(r => (S(r, "Section"), S(r, "Category"), new CategoryNote(S(r, "Group"), S(r, "Line"))))];
    }

    private static int IndexOf(string section, string category)
    {
        for (var i = 0; i < All.Count; i++)
            if (string.Equals(All[i].Section, section, StringComparison.OrdinalIgnoreCase)
                && string.Equals(All[i].Category, category, StringComparison.OrdinalIgnoreCase)) return i;
        return -1;
    }

    public static CategoryNote? Of(string section, string category) => IndexOf(section, category) is var i and >= 0 ? All[i].Note : null;

    /// <summary>The order of a Category in <see cref="All"/>; one not listed goes last.</summary>
    public static int Order(string section, string category) => IndexOf(section, category) is var i and >= 0 ? i : int.MaxValue;

    /// <summary>A line for a Category not listed: its first three Tweaks' names, "…" when it has more.</summary>
    public static string FromNames(IReadOnlyList<string> names) =>
        string.Join(", ", names.Take(3)) + (names.Count > 3 ? ", …" : "");
}

/// <summary>A link in a page's crumb line (above its heading): its text and where it goes.</summary>
public sealed class CrumbLink(string text, Action open)
{
    public string Text { get; } = text;
    public IRelayCommand OpenCommand { get; } = new RelayCommand(open);
}
