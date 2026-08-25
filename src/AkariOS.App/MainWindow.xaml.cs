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

        // Playbook-first shell: the nav pane lists the wizard steps as pages.
        // The ISO builder (BuilderPage + pipeline) is kept in the codebase but is not
        // exposed in this UI; it may return later as an advanced feature.
        _navigation.SetFrame(ContentFrame);
        _navigation.NavigateTo<LicensePage>();
        _navigation.Navigated += (_, _) => RefreshShellState();
        RefreshShellState();
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

    /// <summary>Playbook wizard steps, shown as the main nav entries.</summary>
    public IReadOnlyList<NavigationItem> MainNavItems { get; } =
    [
        new("License Agreement", "\uE8FA", typeof(LicensePage)),      // certificate icon
        new("System Check", "\uE9D9", typeof(SystemCheckPage)),       // diagnostic icon
        new("Configuration", "\uE713", typeof(ConfigurationPage)),    // settings icon
        new("Optimization", "\uE9F5", typeof(OptimizationPage)),      // processing icon
        new("Finished", "\uE73E", typeof(FinishedPage)),              // checkmark icon
    ];

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
        // The pane is a step PROGRESS indicator, not free navigation: the only selectable
        // item is Settings (footer). Wizard pages are reached via Next/Back in-page.
        if (args.SelectedItem is NavigationItem item && item.PageType == typeof(SettingsPage))
        {
            if (_navigation.CurrentPageType != typeof(SettingsPage))
                _navigation.NavigateTo<SettingsPage>();
            return;
        }

        // Revert any selection of a wizard step so it never looks clickable-active.
        RefreshShellState();
    }

    private void RefreshShellState()
    {
        var current = _navigation.CurrentPageType;
        var stepIndex = Views.WizardFlow.IndexOf(current);
        var isWizardStep = stepIndex >= 0;

        // Wizard footer only on playbook step pages.
        WizardFooter.Visibility = isWizardStep ? Visibility.Visible : Visibility.Collapsed;

        if (isWizardStep)
        {
            BackButton.IsEnabled = stepIndex > 0;
            NextButton.IsEnabled = CanLeaveStep(stepIndex);

            NextButton.Content = stepIndex switch
            {
                0 => "Accept & Continue",
                var i when i == Views.WizardFlow.Steps.Count - 1 => "Finish",
                _ => "Next",
            };
        }

        // Only Settings is ever selected; wizard steps show state via IsEnabled visuals.
        var settings = FooterNavItems.FirstOrDefault(i => i.PageType == typeof(SettingsPage));
        NavView.SelectedItem = current == typeof(SettingsPage) ? settings : null;
    }

    /// <summary>Per-step gates for advancing forward.</summary>
    private static bool CanLeaveStep(int index) => index switch
    {
        0 => Views.WizardFlow.LicenseAccepted,   // must tick the license checkbox
        2 => Views.ConfigurationPage.ConfiguredAtLeastOnce, // must run Select Options
        _ => true,
    };

    private void OnWizardBack(object sender, RoutedEventArgs e)
    {
        var current = Views.WizardFlow.IndexOf(_navigation.CurrentPageType);
        if (current > 0)
        {
            _navigation.NavigateTo(Views.WizardFlow.Steps[current - 1].PageType);
            RefreshShellState();
        }
    }

    private void OnWizardNext(object sender, RoutedEventArgs e)
    {
        var current = Views.WizardFlow.IndexOf(_navigation.CurrentPageType);
        if (current < 0 || !CanLeaveStep(current)) return;

        // Leaving the license step records acceptance from the page's checkbox.
        if (_navigation.CurrentPageType == typeof(LicensePage)
            && ContentFrame.Content is LicensePage license)
        {
            Views.WizardFlow.LicenseAccepted = license.Accepted;
            if (!Views.WizardFlow.LicenseAccepted) return; // gate: checkbox unticked
        }

        // Leaving Configuration captures the selected option names for the engine run.
        if (_navigation.CurrentPageType == typeof(ConfigurationPage)
            && ContentFrame.Content is ConfigurationPage config)
        {
            WizardFlow.SelectedOptions.Clear();
            WizardFlow.SelectedOptions.AddRange(Views.ConfigurationPage.SelectedOptionsList);
        }

        if (current < Views.WizardFlow.Steps.Count - 1)
        {
            _navigation.NavigateTo(Views.WizardFlow.Steps[current + 1].PageType);
            RefreshShellState();
        }
    }

    private void OnDiscordClick(object sender, RoutedEventArgs e) =>
        _ = Windows.System.Launcher.LaunchUriAsync(new Uri("https://discord.gg/UjjmYM6ytj"));

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
