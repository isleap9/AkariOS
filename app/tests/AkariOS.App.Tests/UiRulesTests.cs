using System.IO;
using System.Text.RegularExpressions;

namespace AkariOS.App.Tests;

/// <summary>The UI rules of src/UI, kept in the native app's source (ADR 0006, the motion plan).</summary>
public class UiRulesTests
{
    private static string AppFolder()
    {
        for (var d = new DirectoryInfo(AppContext.BaseDirectory); d != null; d = d.Parent)
            if (File.Exists(Path.Combine(d.FullName, "AGENTS.md"))) return Path.Combine(d.FullName, "app", "AkariOS.App");
        throw new DirectoryNotFoundException("the repo root was not found");
    }

    private static IEnumerable<(string File, string Text)> Sources(params string[] patterns) =>
        patterns.SelectMany(p => Directory.GetFiles(AppFolder(), p, SearchOption.AllDirectories))
            .Where(f => !f.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}") && !f.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}"))
            .Select(f => (Path.GetFileName(f), File.ReadAllText(f)));

    [Fact]
    public void Animations_start_only_in_the_motion_service()
    {
        var bad = Sources("*.cs").Where(s => s.File != "Motion.cs" && s.Text.Contains("BeginAnimation(")).Select(s => s.File).ToList();
        Assert.True(bad.Count == 0, "BeginAnimation outside Look/Motion.cs: " + string.Join(", ", bad));
    }

    [Fact]
    public void Xaml_is_parsed_only_through_AkariXaml()
    {
        var bad = Sources("*.cs").Where(s => s.File != "AkariXaml.cs" && Regex.IsMatch(s.Text, @"XamlReader\.(Parse|Load)\(")).Select(s => s.File).ToList();
        Assert.True(bad.Count == 0, "XamlReader outside AkariXaml.cs: " + string.Join(", ", bad));
    }

    [Fact]
    public void No_colours_but_the_themes()
    {
        var bad = Sources("*.cs", "*.xaml")
            .Where(s => Regex.IsMatch(s.Text, @"""#[0-9A-Fa-f]{3,8}""|Color\.FromRgb|Color\.FromArgb|Brushes\.(?!Transparent)\w+"))
            .Select(s => s.File).ToList();
        Assert.True(bad.Count == 0, "a colour outside Theme.Dark / Theme.Light: " + string.Join(", ", bad));
    }
}
