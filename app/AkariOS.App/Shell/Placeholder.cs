using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;

namespace AkariOS.App.Shell;

/// <summary>A page not built yet in the native app: says which milestone brings it (Home and About come in N2).</summary>
public static class Placeholder
{
    public static string Milestone(string page) => page switch
    {
        "Home" or "About" => "N2",
        "Install AkariOS" or "Optimize" => "N3",
        "Downloads" or "Remove apps" => "N5",
        "Unattend Generator" => "N9",
        "ISO Builder" => "N10",
        _ when page.StartsWith(ShellLayout.CataloguePrefix, StringComparison.Ordinal) => "N3",
        _ => "a later milestone",
    };

    public static UIElement For(string page)
    {
        var panel = new StackPanel { Margin = new Thickness(8, 24, 8, 24) };
        var icon = Icons.Make("wrench", 40, "Mu");
        icon.HorizontalAlignment = HorizontalAlignment.Left;
        icon.Margin = new Thickness(0, 0, 0, 16);
        panel.Children.Add(icon);
        var title = new TextBlock { Text = $"Not in the native app yet", FontSize = 20, FontWeight = FontWeights.Bold };
        title.SetResourceReference(TextBlock.FontFamilyProperty, "FontDisplay");
        panel.Children.Add(title);
        var line = new TextBlock { Text = $"{page} comes with {Milestone(page)} (docs/plans/2026-10-31-native-app.md). The PowerShell app has it today.", Margin = new Thickness(0, 8, 0, 0), TextWrapping = TextWrapping.Wrap };
        line.SetResourceReference(TextBlock.ForegroundProperty, "Mu");
        panel.Children.Add(line);
        return panel;
    }
}
