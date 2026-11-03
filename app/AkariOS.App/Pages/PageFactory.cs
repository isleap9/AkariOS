using System.Windows;
using AkariOS.App.Shell;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>The page for a page name: Home, About, the Catalogue's pages and its search (from any page that doesn't
/// search itself: there is no Legacy here), the rest placeholders until their milestones.</summary>
public static class PageFactory
{
    public static Func<string, UIElement> For(AppServices s)
    {
        var catalogue = s.Catalogue ??= new CatalogueView(s);
        var install = s.Install ??= new InstallPage(s);
        return page =>
        {
            var q = s.Shell.Search.Trim();
            if (Catalogue.Split(page) is not null || (q.Length > 0 && !ShellLayout.OwnSearch(page))) return catalogue.Build(page, q);
            return page switch
            {
                "Home" => HomePage.Build(s),
                "Install AkariOS" => install.Build(q),
                "About" => AboutPage.Build(s),
                _ => Placeholder.For(page),
            };
        };
    }
}
