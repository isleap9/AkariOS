using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.Shell;

/// <summary>
/// The window's state (src/UI/Shell.ps1's Show-Page, Set-Busy and the top bar): the current page and its header, the
/// search, the status bar. The window binds to it; pages are made for <see cref="Page"/> (N3 fills them in).
/// </summary>
public sealed partial class ShellViewModel : ObservableObject
{
    public ShellViewModel(string version)
    {
        Version = $"AkariOS {version}";
        Refresh();
    }

    public string Version { get; }

    /// <summary>The page shown: a tab's page, "Remove apps", "About", or a Catalogue page ("Catalogue:Section/Category").</summary>
    [ObservableProperty]
    public partial string Page { get; set; } = "Home";

    [ObservableProperty]
    public partial string Search { get; set; } = "";

    [ObservableProperty]
    public partial string Heading { get; set; } = "";

    [ObservableProperty]
    public partial string Sub { get; set; } = "";

    [ObservableProperty]
    public partial string Glyph { get; set; } = "house";

    /// <summary>Home has no header: its hero is the title.</summary>
    [ObservableProperty]
    public partial bool HeaderVisible { get; set; }

    [ObservableProperty]
    public partial string SearchHint { get; set; } = "Search";

    [ObservableProperty]
    public partial string Tab { get; set; } = "Home";

    /// <summary>Something runs (the status bar's ring and bar); Locked: the page can't be used meanwhile.</summary>
    [ObservableProperty]
    public partial bool Busy { get; set; }

    [ObservableProperty]
    public partial bool Locked { get; set; }

    [ObservableProperty]
    public partial string StatusText { get; set; } = "Ready";

    /// <summary>How far a job is, 0..1, or null while it doesn't say (the sliding bar).</summary>
    [ObservableProperty]
    public partial double? Progress { get; set; }

    /// <summary>The Optimize page seen last: where the Optimize tab goes.</summary>
    public string LastOptimize { get; private set; } = "Optimize";

    /// <summary>A new page or the search starting / ending: the page comes in again (not on every keystroke).</summary>
    public event Action? PageMoved;

    private string _motionKey = "";
    private string _busyLabel = "Ready";

    private bool _opening;

    partial void OnPageChanged(string value) { if (!_opening) Refresh(); }

    partial void OnSearchChanged(string value) { if (!_opening) Refresh(); }

    /// <summary>Opens a page from a tab, a chip, a tile or a button; the search is cleared.</summary>
    [RelayCommand]
    public void Open(string name)
    {
        if (name == "Optimize") name = LastOptimize;
        // the search cleared and the page changed: one refresh, one page build
        _opening = true;
        try { Search = ""; Page = name; }
        finally { _opening = false; }
        Refresh();
    }

    private void Refresh()
    {
        var q = Search.Trim();
        Tab = ShellLayout.TabOf(Page);
        if (Tab == "Optimize") LastOptimize = Page;
        SearchHint = ShellLayout.SearchHint(Page);
        HeaderVisible = q.Length > 0 || Page != "Home";
        if (q.Length > 0) (Heading, Sub, Glyph) = ("Search", $"Results for \"{q}\"", "search");
        else
        {
            var info = ShellLayout.Pages.GetValueOrDefault(Page) ?? new PageInfo("settings", "");
            var title = Page.StartsWith(ShellLayout.CataloguePrefix, StringComparison.Ordinal) ? Page[(Page.LastIndexOf('/') + 1)..] : Page;
            (Heading, Sub, Glyph) = (title, info.Sub, info.Glyph);
        }
        var key = $"{Page}|{q.Length > 0}";
        if (key != _motionKey)
        {
            _motionKey = key;
            PageMoved?.Invoke();
        }
    }

    /// <summary>Set-Busy: the ring, the label (or "Working…") and the bar; Ready at rest.</summary>
    public void SetBusy(bool on, string label = "", bool locked = true)
    {
        Busy = on;
        Locked = on && locked;
        StatusText = _busyLabel = on ? (label.Length > 0 ? label : "Working…") : "Ready";
        Progress = null;
    }

    /// <summary>A job's progress: the bar filled to done / total, "label (n of total): step".</summary>
    public void SetProgress(int done, int total, string? step)
    {
        if (!Busy) return;
        Progress = total > 0 ? Math.Min(1, (double)done / total) : null;
        StatusText = ShellLayout.ProgressText(_busyLabel, done, total, step);
    }
}
