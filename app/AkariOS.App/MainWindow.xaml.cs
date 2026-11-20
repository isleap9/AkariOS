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
    private readonly InstallViewModel _install;
    private readonly Dictionary<string, NavigationViewItem> _items = new(StringComparer.OrdinalIgnoreCase);
    private string _current = "";
    private bool _closing;

    public MainWindow(INavigationService navigation, IThemeService theme, IMessenger messenger, CatalogueViewModel catalogue, InstallViewModel install, ShellState shell)
    {
        InitializeComponent();
        _install = install;
        _navigation = navigation;
        _theme = theme;
        _catalogue = catalogue;
        Shell = shell;
        AppWindow.Closing += OnClosing;

        Title = App.AppName;
        VersionText.Text = AkariInfo.Version;
        SystemBackdrop = new MicaBackdrop();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        ConfigureWindow();

        foreach (var e in NavTable.Menu) NavView.MenuItems.Add(Item(e));
        foreach (var e in NavTable.Footer) NavView.FooterMenuItems.Add(Item(e));

        _navigation.SetFrame(ContentFrame);
        _navigation.Navigated += (_, _) => BackBtn.IsEnabled = _navigation.CanGoBack;
        Open("Home");

        messenger.Register<ThemeChangedMessage>(this, (r, m) => ((MainWindow)r).ApplyTheme(m.Theme));
        messenger.Register<NavigationRequestedMessage>(this, (r, m) => ((MainWindow)r)._navigation.NavigateTo(m.PageType, m.Parameter));
    }

    /// <summary>The busy toast's state (bound in XAML).</summary>
    public ShellState Shell { get; }

    /// <summary>One-click: the window closes without asking (Program runs the preset in a console after it).</summary>
    public void CloseForOneClick()
    {
        _closing = true;
        Close();
    }

    /// <summary>Opens a page by its key (NavTable.Route), selecting its nav item.</summary>
    public void Open(string key)
    {
        var route = NavTable.Route(key);
        var shown = route.Page == NavPage.Catalogue && route.Query.Length > 0 ? NavTable.SearchPrefix + route.Query : route.Key;
        if (string.Equals(shown, _current, StringComparison.OrdinalIgnoreCase)) return;
        _current = shown;
        Shell.Page = shown;
        switch (route.Page)
        {
            case NavPage.Home: _navigation.NavigateTo<HomePage>(); break;
            case NavPage.Settings: _navigation.NavigateTo<SettingsPage>(); break;
            case NavPage.Install: _navigation.NavigateTo<InstallPage>(); break;
            case NavPage.Catalogue: _navigation.NavigateTo<CataloguePage>(new CatalogueQuery(route.Key, route.Query)); break;
            default:
                var entry = NavTable.Find(key);
                _navigation.NavigateTo<PlaceholderPage>(new Placeholder(entry?.Label ?? key, NavTable.ComingWith(key)));
                break;
        }
        if (route.NavKey is null) NavView.SelectedItem = null;
        else if (_items.TryGetValue(route.NavKey, out var item) && !ReferenceEquals(NavView.SelectedItem, item))
        {
            // a Section's item: its parent (Optimize) open
            if (_items.TryGetValue("Optimize", out var optimize) && route.Page == NavPage.Catalogue) optimize.IsExpanded = true;
            NavView.SelectedItem = item;
        }
    }

    // ---- the search box (Get-AkariSuggestions, Open-AkariSuggestion, Open-AkariSearch)

    private void OnSearchTyped(AutoSuggestBox sender, AutoSuggestBoxTextChangedEventArgs args)
    {
        if (args.Reason != AutoSuggestionBoxTextChangeReason.UserInput) return;
        sender.ItemsSource = _catalogue.Suggest(sender.Text).Select(t => new SearchSuggestion(t)).ToList();
    }

    private void OnSearchSubmitted(AutoSuggestBox sender, AutoSuggestBoxQuerySubmittedEventArgs args)
    {
        // a suggestion: its Category; Enter: every match
        if (args.ChosenSuggestion is SearchSuggestion s) Open(Core.Tweaks.Catalogue.Key(s.Tweak.Section, s.Tweak.Category));
        else if (args.QueryText.Trim().Length > 0) Open(NavTable.SearchPrefix + args.QueryText.Trim());
    }

    // ---- closing: a change running, a Guided Run applying or Safe Mode changes waiting ask first

    private async void OnClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_closing || !(_catalogue.MustAsk || _install.Running)) return;
        args.Cancel = true;
        if (!await _install.CanCloseAsync() || !await _catalogue.CanCloseAsync()) return;
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
        var path = Path.Combine(AppContext.BaseDirectory, "Assets", file);
        return File.Exists(path) ? new BitmapImage(new Uri(path)) : null;
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
        var icon = Path.Combine(AppContext.BaseDirectory, "Assets", "AkariLogo.ico");
        if (File.Exists(icon)) window.SetIcon(icon);
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
