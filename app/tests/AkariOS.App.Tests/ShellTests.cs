using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;

namespace AkariOS.App.Tests;

/// <summary>The shell's table and the view models (no WinUI object: they can't be made in a test host).</summary>
public sealed class ShellTests
{
    private sealed class Navigator : IShellNavigator
    {
        public List<string> Opened { get; } = [];
        public void Open(string key) => Opened.Add(key);
    }

    private sealed class Opener : IShellOpen
    {
        public List<string> Folders { get; } = [];
        public void Url(string url) { }
        public void Folder(string path) => Folders.Add(path);
        public void Program(string path) { }
    }

    private sealed class Theme : IThemeService
    {
        public AppTheme CurrentTheme { get; private set; } = AppTheme.System;
        public Task InitializeAsync() => Task.CompletedTask;
        public Task SetThemeAsync(AppTheme theme) { CurrentTheme = theme; return Task.CompletedTask; }
        public void Toggle() { }
        public Task SetSystemThemeAsync() => SetThemeAsync(AppTheme.System);
    }

    [Fact]
    public void Nav_is_the_PowerShell_apps()
    {
        // Shell.ps1's $AkariNav, Settings in the footer
        Assert.Equal(["Home", "Install AkariOS", "Optimize", "Downloads", "Remove apps", "Install USB", "ISO Builder"], NavTable.Menu.Select(e => e.Key));
        Assert.Equal([NavTable.Settings], NavTable.Footer.Select(e => e.Key));
    }

    [Fact]
    public void Optimize_lists_the_Catalogue_sections()
    {
        var optimize = NavTable.Find("Optimize")!;
        Assert.Equal(Catalogue.Sections.Select(s => Catalogue.Prefix + s), optimize.Children.Select(c => c.Key));
        Assert.Equal("Graphics & Hardware", NavTable.Find(Catalogue.Prefix + "Hardware")!.Label);
    }

    [Fact]
    public void Every_placeholder_names_its_batch()
    {
        foreach (var e in NavTable.All)
        {
            var placeholder = NavTable.Route(e.Key).Page == NavPage.Placeholder;
            Assert.Equal(placeholder, NavTable.ComingWith(e.Key) is not null);
        }
        Assert.Equal(["Downloads", "Remove apps", "Install USB", "ISO Builder"],
            NavTable.All.Where(e => NavTable.Route(e.Key).Page == NavPage.Placeholder).Select(e => e.Key));
    }

    [Fact]
    public void Routes()
    {
        // Optimize = its first Section; a Category selects its Section's item; a search selects none
        Assert.Equal(new NavRoute(NavPage.Catalogue, "Catalogue:Optimize", "Catalogue:Optimize", ""), NavTable.Route("Optimize"));
        Assert.Equal(new NavRoute(NavPage.Catalogue, "Catalogue:Hardware/Graphics", "Catalogue:Hardware", ""), NavTable.Route("Catalogue:Hardware/Graphics"));
        Assert.Equal(new NavRoute(NavPage.Catalogue, "", null, "dns"), NavTable.Route("Search:dns"));
        Assert.Equal(NavPage.Home, NavTable.Route("Home").Page);
        Assert.Equal(NavPage.Settings, NavTable.Route("Settings").Page);
        Assert.Equal(NavPage.Install, NavTable.Route("Install AkariOS").Page);
    }

    [Fact]
    public void Placeholder_says_which_batch()
    {
        var p = new PlaceholderViewModel();
        p.OnNavigatedTo(new Placeholder("ISO Builder", "W8"));
        Assert.Equal("ISO Builder", p.Title);
        Assert.Contains("batch W8", p.Text);
    }
}
