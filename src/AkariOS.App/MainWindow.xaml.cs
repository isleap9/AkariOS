using CommunityToolkit.Mvvm.Messaging;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using AkariOS.App.Views;
using AkariOS.App.ViewModels;
using AkariOS.Framework;
using AkariOS.Framework.Messaging;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.Services;
using Windows.Graphics;
using Windows.UI;


namespace AkariOS.App;

public sealed partial class MainWindow : Window
{
    private readonly INavigationService _navigation;
    private readonly IThemeService _theme;
    private readonly IMessenger _messenger;

    public BuilderViewModel ViewModel { get; }

    public MainWindow(
        BuilderViewModel builderViewModel,
        INavigationService navigation,
        IInfoBarService infoBar,
        IThemeService theme,
        IMessenger messenger)
    {
        InitializeComponent();

        ViewModel = builderViewModel;
        _navigation = navigation;
        InfoBar = infoBar;
        _theme = theme;
        _messenger = messenger;

        Title = App.AppName;

        SystemBackdrop = new MicaBackdrop();

        ExtendsContentIntoTitleBar = true;

        SetTitleBar(AppTitleBar);
        ConfigureWindow();

        // Single page: the shell's pane is the ISO list; the frame shows the details page.
        _navigation.SetFrame(ContentFrame);
        _navigation.NavigateTo<BuilderPage>();
        _navigation.Navigated += (_, _) => RefreshShellState();
        RefreshShellState();

        ViewModel.Isos.CollectionChanged += (_, _) => UpdatePaneHint();

        _messenger.Register<ThemeChangedMessage>(this, (r, m) => ((MainWindow)r).ApplyTheme(m.Theme));
    }

    /// <summary>Global info-bar state bound by the shell.</summary>
    public IInfoBarService InfoBar { get; }

    /// <summary>App name shown in the custom title bar.</summary>
    public string AppTitle => App.AppName;

    /// <summary>App icon shown in the custom title bar.</summary>
    public ImageSource AppIconSource { get; } = LoadAppIcon();

    private static ImageSource LoadAppIcon()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.png");
        return File.Exists(path) ? new BitmapImage(new Uri(path)) : null!;
    }

    /// <summary>Footer items (bottom of the pane).</summary>
    public IReadOnlyList<NavigationItem> FooterNavItems { get; } =
    [
        new("Settings", "\uE713", typeof(SettingsPage)),
    ];

    public void ApplyTheme(AppTheme theme)
    {
        RootElement.RequestedTheme = theme switch
        {
            AppTheme.Light => ElementTheme.Light,
            AppTheme.Dark => ElementTheme.Dark,
            _ => ElementTheme.Default,
        };

        ApplyTitleBarColors(theme);
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        Type? pageType = null;

        switch (args.SelectedItem)
        {
            case NavigationItem item:
                pageType = item.PageType;
                break;
            case NavigationViewItem navItem when navItem.Tag is Type type:
                pageType = type;
                break;
        }

        if (pageType is not null && pageType != _navigation.CurrentPageType)
        {
            _navigation.NavigateTo(pageType);
        }
    }

    private void RefreshShellState()
    {
        var current = _navigation.CurrentPageType;
        var item = FooterNavItems.FirstOrDefault(i => i.PageType == current);

        if (item is not null && !ReferenceEquals(NavView.SelectedItem, item))
        {
            NavView.SelectedItem = item;
        }
    }

    // ===== Pane drag & drop =====

    private void OnPaneDragOver(object sender, DragEventArgs e)
    {
        e.AcceptedOperation = Windows.ApplicationModel.DataTransfer.DataPackageOperation.Copy;
        PaneDropArea.Opacity = 0.75;
    }

    private void OnPaneDragLeave(object sender, DragEventArgs e) => PaneDropArea.Opacity = 1;

    private async void OnPaneDrop(object sender, DragEventArgs e)
    {
        PaneDropArea.Opacity = 1;
        var deferral = e.GetDeferral();
        try
        {
            if (!e.DataView.Contains(Windows.ApplicationModel.DataTransfer.StandardDataFormats.StorageItems))
                return;

            var items = await e.DataView.GetStorageItemsAsync();
            foreach (var item in items.Where(i => i.Path.EndsWith(".iso", StringComparison.OrdinalIgnoreCase)))
                ViewModel.AddIso(item.Path);
        }
        finally
        {
            deferral.Complete();
        }
    }

    private void UpdatePaneHint() =>
        PaneDropHint.Visibility = ViewModel.Isos.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

    private void ConfigureWindow()
    {
        var appWindow = AppWindow;
        appWindow.Resize(new SizeInt32(1100, 700));
        appWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico"));
    }

    private void ApplyTitleBarColors(AppTheme theme)
    {
        var appWindow = AppWindow;
        if (appWindow?.TitleBar is not { } titleBar) return;

        var fg = theme == AppTheme.Light ? Microsoft.UI.Colors.Black : Microsoft.UI.Colors.White;
        var bg = Microsoft.UI.Colors.Transparent;

        titleBar.ForegroundColor = fg;
        titleBar.BackgroundColor = bg;
        titleBar.ButtonForegroundColor = fg;
        titleBar.ButtonBackgroundColor = bg;
        titleBar.ButtonHoverForegroundColor = fg;
        titleBar.ButtonHoverBackgroundColor = Color.FromArgb(0x20, fg.R, fg.G, fg.B);
        titleBar.ButtonPressedForegroundColor = fg;
        titleBar.ButtonPressedBackgroundColor = Color.FromArgb(0x40, fg.R, fg.G, fg.B);
        titleBar.ButtonInactiveForegroundColor = Color.FromArgb(0xFF, 0x80, 0x80, 0x80);
        titleBar.ButtonInactiveBackgroundColor = bg;
    }
}
