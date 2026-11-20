using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.App.Views;
using AkariOS.Core;
using AkariOS.Framework.Messaging;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.Messaging;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Graphics;

namespace AkariOS.App;

/// <summary>
/// The shell (Shell.ps1): a 48 px title bar over Mica, the left NavigationView built from NavTable, the page frame.
/// Pages are keyed by the PowerShell app's page names; one still to come shows a placeholder naming its batch.
/// </summary>
public sealed partial class MainWindow : Window, IShellNavigator
{
    private readonly INavigationService _navigation;
    private readonly IThemeService _theme;
    private readonly CatalogueViewModel _catalogue;
    private readonly ClosingGuard _closingGuard;
    private readonly Dictionary<string, NavigationViewItem> _items = new(StringComparer.OrdinalIgnoreCase);
    private string _current = "";
    private readonly Queue<string> _trail = new();
    private bool _closing;

    private readonly SearchTip _searchTip;

    public MainWindow(INavigationService navigation, IThemeService theme, IMessenger messenger, CatalogueViewModel catalogue, ClosingGuard closing, ShellState shell,
        SearchTip searchTip)
    {
        InitializeComponent();
        _searchTip = searchTip;
        _closingGuard = closing;
        _navigation = navigation;
        _theme = theme;
        _catalogue = catalogue;
        Shell = shell;
        AppWindow.Closing += OnClosing;
        // each toast goes by itself after its time (Show-AkariToast's timer)
        Shell.Toasts.CollectionChanged += (_, e) =>
        {
            foreach (var t in e.NewItems?.OfType<Toast>() ?? []) Expire(t);
        };

        Title = App.AppName;
        VersionText.Text = AkariInfo.Version;
        SystemBackdrop = new MicaBackdrop();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        ConfigureWindow();

        foreach (var e in NavTable.Menu) NavView.MenuItems.Add(Item(e));
        foreach (var e in NavTable.Footer) NavView.FooterMenuItems.Add(Item(e));

        // the trail a UI error is logged with (Describe): WinUI's own errors come with no stack trace
        NavView.PaneOpened += (_, _) => Note("pane opened");
        NavView.PaneClosed += (_, _) => Note("pane closed");
        NavView.DisplayModeChanged += (_, e) => Note($"display mode {e.DisplayMode}");
        NavView.Expanding += (_, e) => Note($"expanding {(e.ExpandingItemContainer?.Tag as string) ?? "?"}");
        NavView.Collapsed += (_, e) => Note($"collapsed {(e.CollapsedItemContainer?.Tag as string) ?? "?"}");
        NavView.Collapsed += OnNavCollapsed;
        NavView.Expanding += OnNavExpanding;
        RootElement.SizeChanged += (_, e) => Note($"size {(int)e.NewSize.Width}x{(int)e.NewSize.Height}");

        _navigation.SetFrame(ContentFrame);
        _navigation.Navigated += (_, _) => BackBtn.IsEnabled = _navigation.CanGoBack;
        Open("Home");
        ShowSearchTipLater();

        messenger.Register<ThemeChangedMessage>(this, (r, m) => ((MainWindow)r).ApplyTheme(m.Theme));
        messenger.Register<NavigationRequestedMessage>(this, (r, m) => ((MainWindow)r)._navigation.NavigateTo(m.PageType, m.Parameter));
    }

    /// <summary>The busy toast's state (bound in XAML).</summary>
    public ShellState Shell { get; }

    private void Note(string what)
    {
        if (_trail.Count == 12) _trail.Dequeue();
        _trail.Enqueue($"{DateTime.Now:HH:mm:ss} {what}");
    }

    /// <summary>The window's state and its last steps, for akari.log when a UI error happens.</summary>
    public string Describe()
    {
        try
        {
            var selected = (NavView.SelectedItem as NavigationViewItem)?.Tag as string ?? "none";
            return $"page {_current}, nav item {selected}, display mode {NavView.DisplayMode}, pane {(NavView.IsPaneOpen ? "open" : "closed")}, " +
                   $"width {(int)RootElement.ActualWidth}; last steps: {string.Join(" / ", _trail)}";
        }
        catch (Exception e) { return $"(the window's state could not be read: {e.Message})"; }
    }

    /// <summary>One-click: the window closes without asking (Program runs the preset in a console after it).</summary>
    public void CloseForOneClick()
    {
        _closing = true;
        Close();
    }

    /// <summary>Opens a page by its key (NavTable.Route), selecting its nav item.</summary>
    public void Open(string key) => Open(key, "");

    // flash: a search suggestion's Tweak, its card scrolled to and flashed (opened again even on its own page)
    private void Open(string key, string flash)
    {
        var route = NavTable.Route(key);
        var shown = route.Page == NavPage.Catalogue && route.Query.Length > 0 ? NavTable.SearchPrefix + route.Query : route.Key;
        if (flash.Length == 0 && string.Equals(shown, _current, StringComparison.OrdinalIgnoreCase)) return;
        _current = shown;
        Shell.Page = shown;
        Note($"open {shown}");
        switch (route.Page)
        {
            case NavPage.Home: _navigation.NavigateTo<HomePage>(); break;
            case NavPage.Settings: _navigation.NavigateTo<SettingsPage>(); break;
            case NavPage.Install: _navigation.NavigateTo<InstallPage>(); break;
            case NavPage.Downloads: _navigation.NavigateTo<DownloadsPage>(); break;
            case NavPage.RemoveApps: _navigation.NavigateTo<RemoveAppsPage>(); break;
            case NavPage.Unattend: _navigation.NavigateTo<UnattendPage>(); break;
            case NavPage.Iso: _navigation.NavigateTo<IsoBuilderPage>(); break;
            case NavPage.Optimize: _navigation.NavigateTo<OptimizePage>(); break;
            case NavPage.Catalogue: _navigation.NavigateTo<CataloguePage>(new CatalogueQuery(route.Key, route.Query, flash)); break;
            default:
                var entry = NavTable.Find(key);
                _navigation.NavigateTo<PlaceholderPage>(new Placeholder(entry?.Label ?? key, NavTable.ComingWith(key)));
                break;
        }
        _navKey = route.NavKey;
        if (route.NavKey is null) NavView.SelectedItem = null;
        else if (_items.TryGetValue(route.NavKey, out var item) && !ReferenceEquals(NavView.SelectedItem, item))
        {
            // a Section's item: its parent (Optimize) opened first, the child selected once that is done (SelectLater)
            if (route.Page == NavPage.Catalogue && _items.TryGetValue("Optimize", out var optimize) && !optimize.IsExpanded)
            {
                optimize.IsExpanded = true;
                SelectLater();
            }
            else NavView.SelectedItem = item;
        }
    }

    // ---- the nav's selection around a group expanding and collapsing
    //
    // WinUI's NavigationView throws "invalid vector subscript" (ArgumentOutOfRangeException, no stack trace) when a group
    // expands while one of its children is the selected item (seen on Optimize: every second click on it). So a group
    // collapsing hands the selection to itself, and a group expanding gets its child back once the expansion is done.

    private string? _navKey;

    private void OnNavCollapsed(NavigationView sender, NavigationViewItemCollapsedEventArgs args)
    {
        if (args.CollapsedItemContainer is NavigationViewItem parent && parent.MenuItems.Contains(NavView.SelectedItem)) NavView.SelectedItem = parent;
    }

    private void OnNavExpanding(NavigationView sender, NavigationViewItemExpandingEventArgs args) => SelectLater();

    // the page's own item, after the expansion under way has finished
    private void SelectLater() => DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () =>
    {
        if (_navKey is not null && _items.TryGetValue(_navKey, out var item) && !ReferenceEquals(NavView.SelectedItem, item)
            // a child of a group closed again meanwhile stays unselected (its group shows as selected)
            && !_items.Values.Any(p => p.MenuItems.Contains(item) && !p.IsExpanded))
            NavView.SelectedItem = item;
    });

    // ---- the search box (Get-AkariSuggestions, Open-AkariSuggestion, Open-AkariSearch)

    private void OnSearchTyped(AutoSuggestBox sender, AutoSuggestBoxTextChangedEventArgs args)
    {
        if (args.Reason != AutoSuggestionBoxTextChangeReason.UserInput) return;
        sender.ItemsSource = _catalogue.Suggest(sender.Text).Select(t => new SearchSuggestion(t)).ToList();
    }

    private void OnSearchSubmitted(AutoSuggestBox sender, AutoSuggestBoxQuerySubmittedEventArgs args)
    {
        // a suggestion: its Category; Enter: every match
        if (args.ChosenSuggestion is SearchSuggestion s)
        {
            // Open-AkariSuggestion: the box emptied, the Tweak's Category, its card flashed
            sender.Text = "";
            Open(Core.Tweaks.Catalogue.Key(s.Tweak.Section, s.Tweak.Category), s.Tweak.Id);
        }
        else if (args.QueryText.Trim().Length > 0) Open(NavTable.SearchPrefix + args.QueryText.Trim());
    }

    private void Expire(Toast t)
    {
        var timer = DispatcherQueue.CreateTimer();
        timer.Interval = TimeSpan.FromSeconds(t.Seconds);
        timer.IsRepeating = false;
        timer.Tick += (s, _) =>
        {
            s.Stop();
            Shell.Dismiss(t);
        };
        timer.Start();
    }

    // ---- the keys: Ctrl+F / Ctrl+E to the search box (the pane opened first when it is compact), Alt+Left back

    private void OnSearchKey(Microsoft.UI.Xaml.Input.KeyboardAccelerator sender, Microsoft.UI.Xaml.Input.KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        if (!NavView.IsPaneOpen) NavView.IsPaneOpen = true;
        SearchBox.Focus(FocusState.Keyboard);
    }

    private void OnBackKey(Microsoft.UI.Xaml.Input.KeyboardAccelerator sender, Microsoft.UI.Xaml.Input.KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        OnBack(this, new RoutedEventArgs());
    }

    // ---- the first run's search tip: on Home, 1.4 s after the window opens, once ever

    private void ShowSearchTipLater()
    {
        var timer = DispatcherQueue.CreateTimer();
        timer.Interval = TimeSpan.FromMilliseconds(1400);
        timer.IsRepeating = false;
        timer.Tick += async (t, _) =>
        {
            t.Stop();
            try
            {
                if (_current != "Home" || !NavView.IsPaneOpen || !await _searchTip.ShouldShowAsync()) return;
                SearchTipView.Subtitle = SearchTip.Text(_catalogue.Tweaks.Count);
                SearchTipView.IsOpen = true;
            }
            catch (Exception e) { Note($"search tip: {e.Message}"); }
        };
        timer.Start();
    }

    private void OnSearchTipGotIt(TeachingTip sender, object args) => sender.IsOpen = false;

    private async void OnSearchTipClosed(TeachingTip sender, TeachingTipClosedEventArgs args)
    {
        try { await _searchTip.SeenAsync(); }
        catch (Exception e) { Note($"search tip: {e.Message}"); }
    }

    // ---- closing: anything running or waiting asks once (ClosingGuard), then Safe Mode changes waiting

    private async void OnClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_closing || !_closingGuard.MustAsk) return;
        args.Cancel = true;
        try
        {
            if (!await _closingGuard.CanCloseAsync()) return;
        }
        catch (Exception e)
        {
            // a dialog already open (the window closed from the taskbar while one asks): stays open
            Note($"closing: {e.Message}");
            return;
        }
        _closing = true;
        Close();
    }

    /// <summary>The accent changed: WinUI's theme brushes read the new SystemAccentColor* when the theme is applied
    /// again (switched to the other one and back).</summary>
    public void RefreshTheme()
    {
        var requested = RootElement.RequestedTheme;
        RootElement.RequestedTheme = RootElement.ActualTheme == ElementTheme.Dark ? ElementTheme.Light : ElementTheme.Dark;
        RootElement.RequestedTheme = requested;
    }

    public void ApplyTheme(AppTheme theme)
    {
        RootElement.RequestedTheme = theme switch
        {
            AppTheme.Light => ElementTheme.Light,
            AppTheme.Dark => ElementTheme.Dark,
            _ => ElementTheme.Default,
        };
        Logo.Source = LoadLogo(RootElement.ActualTheme == ElementTheme.Light ? "AkariLogo-light.png" : "AkariLogo-dark.png");
        ApplyTitleBarColors(theme);
    }

    private NavigationViewItem Item(NavEntry e)
    {
        var item = new NavigationViewItem { Content = e.Label, Tag = e.Key, Icon = new FontIcon { Glyph = e.Glyph } };
        foreach (var c in e.Children) item.MenuItems.Add(Item(c));
        _items[e.Key] = item;
        return item;
    }

    private void OnNavInvoked(NavigationView sender, NavigationViewItemInvokedEventArgs args)
    {
        if (args.InvokedItemContainer?.Tag is string key) Open(key);
    }

    private void OnBack(object sender, RoutedEventArgs e)
    {
        if (!_navigation.CanGoBack) return;
        _navigation.GoBack();
        _current = "";
    }

    private static ImageSource? LoadLogo(string file)
    {
        return AssetFiles.Default.File(file) is { } path ? new BitmapImage(new Uri(path)) : null;
    }

    private AppWindow GetAppWindow() =>
        AppWindow.GetFromWindowId(Microsoft.UI.Win32Interop.GetWindowIdFromWindow(WinRT.Interop.WindowNative.GetWindowHandle(this)));

    private void ConfigureWindow()
    {
        var window = GetAppWindow();
        var area = DisplayArea.GetFromWindowId(window.Id, DisplayAreaFallback.Nearest).WorkArea;
        var width = Math.Min(1280, area.Width - 60);
        var height = Math.Min(860, area.Height - 80);
        window.Resize(new SizeInt32(width, height));
        window.Move(new PointInt32(area.X + (area.Width - width) / 2, area.Y + (area.Height - height) / 2));
        if (AssetFiles.Default.File("AkariLogo.ico") is { } icon) window.SetIcon(icon);
        ApplyTitleBarColors(_theme.CurrentTheme);
    }

    private void ApplyTitleBarColors(AppTheme theme)
    {
        var bar = GetAppWindow().TitleBar;
        var dark = theme switch
        {
            AppTheme.Dark => true,
            AppTheme.Light => false,
            _ => RootElement.ActualTheme == ElementTheme.Dark,
        };
        var fore = dark ? Microsoft.UI.Colors.White : Microsoft.UI.Colors.Black;
        bar.ButtonForegroundColor = fore;
        bar.ButtonHoverForegroundColor = fore;
        bar.ButtonBackgroundColor = Microsoft.UI.Colors.Transparent;
        bar.ButtonInactiveBackgroundColor = Microsoft.UI.Colors.Transparent;
    }
}
