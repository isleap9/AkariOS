using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using AkariOS.App.Look;
using AkariOS.App.Shell;

namespace AkariOS.App;

/// <summary>
/// The window's glue (what binding can't do): the tabs and their pill, the width rules, the search box and Ctrl+K,
/// the caption buttons, the status bar's ring and fill, a new page's entrance. The state is ShellViewModel's.
/// </summary>
public partial class MainWindow : Window
{
    private readonly ThemeService _theme;
    private readonly ShellViewModel _vm;
    private readonly Func<string, UIElement> _pages;
    private readonly List<(RadioButton Button, FrameworkElement Icon, TextBlock Label, string Name)> _tabs = [];
    private bool _sync;
    private bool _narrow;

    /// <param name="resources">Tests only: the shared resources, when there is no Application to hold them.</param>
    public MainWindow(ThemeService theme, ShellViewModel vm, Func<string, UIElement> pages, IEnumerable<ResourceDictionary>? resources = null)
    {
        foreach (var d in resources ?? []) Resources.MergedDictionaries.Add(d);
        InitializeComponent();
        (_theme, _vm, _pages) = (theme, vm, pages);
        DataContext = vm;
        try { Icon = BitmapFrame.Create(Assets.Icon); } catch (Exception) { }
        // opens wide enough for the whole top bar (1360 x 800) when the screen has room, else as big as it allows
        var area = SystemParameters.WorkArea;
        Width = Math.Max(MinWidth, Math.Min(1360, area.Width - 40));
        Height = Math.Max(MinHeight, Math.Min(800, area.Height - 40));
        WindowFrame.Attach(this, Body, theme);
        theme.Changed += UpdateLogo;
        UpdateLogo();

        BuildTabs();
        Motion.PillGroup(Tabs, TabPill);
        Motion.SmoothScroll(PageScroll);
        CapMin.Click += (_, _) => SystemCommands.MinimizeWindow(this);
        CapMax.Click += (_, _) => { if (WindowState == WindowState.Maximized) SystemCommands.RestoreWindow(this); else SystemCommands.MaximizeWindow(this); };
        CapClose.Click += (_, _) => Close();
        StateChanged += (_, _) => OnStateChanged();
        SizeChanged += (_, _) => UpdateWidth(ActualWidth);
        SearchBtn.Click += (_, _) => OpenSearch();
        SearchInput.LostKeyboardFocus += (_, _) => { if (SearchInput.Text.Length == 0) SetSearchOpen(false); };
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.K && Keyboard.Modifiers == ModifierKeys.Control) { OpenSearch(); e.Handled = true; }
        };

        vm.PropertyChanged += OnViewModelChanged;
        vm.PageMoved += ShowPage;
        Icons.Set(HeaderIcon, vm.Glyph);
        ShowPage();
        SyncTabs();
    }

    private void UpdateLogo()
    {
        try { Logo.Source = Assets.Image(Assets.LogoFor(_theme.Current)); } catch (Exception) { }
    }

    private void BuildTabs()
    {
        foreach (var (name, icon) in ShellLayout.Tabs)
        {
            var ic = Icons.Make(icon, 16, "Inherit");
            ic.VerticalAlignment = VerticalAlignment.Center;
            ic.Margin = new Thickness(0, 0, 8, 0);
            var label = new TextBlock { Text = name, VerticalAlignment = VerticalAlignment.Center };
            var content = new StackPanel { Orientation = Orientation.Horizontal };
            content.Children.Add(ic);
            content.Children.Add(label);
            var rb = new RadioButton { Content = content, Tag = name, GroupName = "tabs" };
            rb.SetResourceReference(StyleProperty, "Tab");
            Tabs.Children.Add(rb);
            _tabs.Add((rb, ic, label, name));
        }
        Tabs.AddHandler(ToggleButton.CheckedEvent, new RoutedEventHandler((_, e) =>
        {
            if (!_sync && e.OriginalSource is RadioButton { Tag: string tab }) _vm.Open(tab);
        }));
    }

    private void SyncTabs()
    {
        _sync = true;
        try { foreach (var t in _tabs) t.Button.IsChecked = t.Name == _vm.Tab; }
        finally { _sync = false; }
    }

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(ShellViewModel.Tab): SyncTabs(); break;
            case nameof(ShellViewModel.Glyph): Icons.Set(HeaderIcon, _vm.Glyph); break;
            case nameof(ShellViewModel.Busy):
                StatusDot.Visibility = _vm.Busy ? Visibility.Collapsed : Visibility.Visible;
                StatusRing.Visibility = StatusBar.Visibility = _vm.Busy ? Visibility.Visible : Visibility.Collapsed;
                break;
            case nameof(ShellViewModel.Locked): Page.IsEnabled = !_vm.Locked; break;
            case nameof(ShellViewModel.Progress): UpdateProgress(); break;
        }
    }

    // the fill glides to the share done; a bar that was hidden starts there
    private void UpdateProgress()
    {
        var on = _vm.Progress is not null;
        StatusLoop.Visibility = on ? Visibility.Collapsed : Visibility.Visible;
        var was = StatusFill.Visibility == Visibility.Visible;
        StatusFill.Visibility = on ? Visibility.Visible : Visibility.Collapsed;
        if (_vm.Progress is { } share) Motion.Start(StatusFill, MotionKind.Fill, was ? null : share, share, "Slow");
    }

    /// <summary>A new page (or the search starting / ending): built, then the surface rises and the header fades in.</summary>
    private void ShowPage()
    {
        Motion.ResetScroll(PageScroll);
        Page.Content = _pages(_vm.Page);
        Motion.Entrance(Page, MotionKind.Rise);
        Motion.Entrance(PageHeader, MotionKind.Fade, speed: "Base");
    }

    private void OnStateChanged()
    {
        var max = WindowState == WindowState.Maximized;
        // maximized, Windows pushes the frame past the screen edge: pad it back in
        Shell.Margin = new Thickness(max ? 8 : 0);
        Icons.Set(CapMaxGlyph, max ? "copy" : "square");
        CapMax.ToolTip = max ? "Restore" : "Maximize";
    }

    // narrow window: under 1320 px the search is an icon button and the tabs show text only; under 1000 the wordmark
    // goes and the tabs take their short labels
    private void UpdateWidth(double width)
    {
        _narrow = ShellLayout.Narrow(width);
        TitleText.Visibility = ShellLayout.Wordmark(width) ? Visibility.Visible : Visibility.Collapsed;
        var (icons, _) = ShellLayout.TabLayout(width);
        foreach (var t in _tabs)
        {
            t.Icon.Visibility = icons ? Visibility.Visible : Visibility.Collapsed;
            t.Label.Text = ShellLayout.TabLabel(t.Name, width);
        }
        SetSearchOpen(SearchInput.Text.Length > 0 || SearchInput.IsKeyboardFocusWithin);
    }

    private void SetSearchOpen(bool open)
    {
        var show = open || !_narrow;
        SearchBox.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        SearchBtn.Visibility = show ? Visibility.Collapsed : Visibility.Visible;
    }

    private void OpenSearch()
    {
        SetSearchOpen(true);
        UpdateLayout();
        SearchInput.Focus();
        SearchInput.SelectAll();
    }
}
