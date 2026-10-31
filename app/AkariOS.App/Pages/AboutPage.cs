using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;

namespace AkariOS.App.Pages;

/// <summary>About's data, from the shared src/UI/About.psd1: links (an empty Url = hidden), credits, license.</summary>
public sealed record AboutData(
    IReadOnlyList<(string Name, string Url)> Links,
    IReadOnlyList<(string Name, string Text, string Url)> Credits,
    string FullCredits,
    string License,
    string LicenseUrl)
{
    public const string Releases = "https://github.com/isleap9/AkariOS/releases";

    public static AboutData Read(ISourceFiles files)
    {
        var h = (PsHashtable)PsData.Parse(files.ReadText("src/UI/About.psd1")).Value!;
        static string S(PsHashtable t, string k) => PsSemantics.Text(t.Get(k)) ?? "";
        var lic = (PsHashtable)h.Get("License")!;
        return new AboutData(
            PsSemantics.AsList(h.Get("Links")).OfType<PsHashtable>().Select(l => (S(l, "Name"), S(l, "Url"))).ToList(),
            PsSemantics.AsList(h.Get("Credits")).OfType<PsHashtable>().Select(c => (S(c, "Name"), S(c, "Text"), S(c, "Url"))).ToList(),
            S(h, "FullCredits"), S(lic, "Text"), S(lic, "Url"));
    }
}

/// <summary>
/// About (src/UI/About.ps1): the version (update checks come with N4), Links (plus Open log folder), Credits (each
/// name a link), License; the cards in one column on the left, at most 800 px wide; Back leads Home.
/// </summary>
public static class AboutPage
{
    public static UIElement Build(AppServices s)
    {
        var data = AboutData.Read(s.Engine.Files);
        var stack = new StackPanel();

        var (version, vbody) = Parts.Card($"AkariOS {AkariInfo.Version}");
        var status = Parts.Text("Update checks come with N4: for a newer version, see the releases on GitHub.", 13, "Mu");
        status.Margin = new Thickness(0, 0, 0, 12);
        vbody.Children.Add(status);
        var bar = new StackPanel { Orientation = Orientation.Horizontal };
        bar.Children.Add(Parts.Button("Open on GitHub", click: () => s.Open.Url(AboutData.Releases)));
        vbody.Children.Add(bar);
        stack.Children.Add(version);

        var (links, lbody) = Parts.Card("Links");
        var wrap = new WrapPanel();
        foreach (var (name, url) in data.Links.Where(l => l.Url.Length > 0)) wrap.Children.Add(Parts.Button(name, click: () => s.Open.Url(url)));
        wrap.Children.Add(Parts.Button("Open log folder", click: () => s.Open.Folder(s.LogFolder)));
        lbody.Children.Add(wrap);
        stack.Children.Add(links);

        var (credits, cbody) = Parts.Card("Credits");
        foreach (var (name, text, url) in data.Credits)
        {
            var row = new Grid { Margin = new Thickness(0, 0, 0, 6) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            var n = Parts.Link(name, url, s.Open.Url);
            n.FontWeight = FontWeights.SemiBold;
            n.VerticalAlignment = VerticalAlignment.Center;
            var t = Parts.Text(text, 13, "Mu");
            t.VerticalAlignment = VerticalAlignment.Center;
            Grid.SetColumn(t, 1);
            row.Children.Add(n);
            row.Children.Add(t);
            cbody.Children.Add(row);
        }
        var full = Parts.Button("Full credits", click: () => s.Open.Url(data.FullCredits));
        full.HorizontalAlignment = HorizontalAlignment.Left;
        full.Margin = new Thickness(0, 6, 0, 0);
        cbody.Children.Add(full);
        stack.Children.Add(credits);

        var (license, libody) = Parts.Card("License");
        var lp = new StackPanel { Orientation = Orientation.Horizontal };
        var lt = Parts.Text(data.License, 13, "Mu");
        lt.VerticalAlignment = VerticalAlignment.Center;
        lp.Children.Add(lt);
        var view = Parts.Button("View license", click: () => s.Open.Url(data.LicenseUrl));
        view.Margin = new Thickness(12, 0, 0, 0);
        lp.Children.Add(view);
        libody.Children.Add(lp);
        stack.Children.Add(license);

        var back = Parts.Button("Back", click: () => s.Shell.Open("Home"));
        back.HorizontalAlignment = HorizontalAlignment.Left;
        back.MinWidth = 96;
        stack.Children.Add(back);

        // one readable column on the left: it fills the page up to 800 px, so every card has the same width
        var column = new Grid();
        column.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star), MaxWidth = 800 });
        column.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0, GridUnitType.Auto) });
        column.Children.Add(stack);
        return column;
    }
}
