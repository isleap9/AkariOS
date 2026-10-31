using System.Windows;
using AkariOS.App.Shell;

namespace AkariOS.App.Pages;

/// <summary>The page for a page name: Home and About now, the rest placeholders until their milestones.</summary>
public static class PageFactory
{
    public static Func<string, UIElement> For(AppServices s) => page => page switch
    {
        "Home" => HomePage.Build(s),
        "About" => AboutPage.Build(s),
        _ => Placeholder.For(page),
    };
}
