using System.Xml.Linq;

namespace AkariOS.App.Services;

/// <summary>One selectable option on a playbook feature page.</summary>
public sealed class PlaybookOption
{
    public required string Name { get; init; }
    public required string Text { get; init; }
    public bool DefaultChecked { get; init; }

    /// <summary>Live selection state (defaults to DefaultChecked).</summary>
    public bool IsSelected { get; set; } = true;

    public PlaybookOption() { }

    public static PlaybookOption Create(string name, string text, bool defaultChecked) =>
        new() { Name = name, Text = text, DefaultChecked = defaultChecked, IsSelected = defaultChecked };
}

/// <summary>A feature page from playbook.conf (a group of related options).</summary>
public sealed class PlaybookFeaturePage
{
    public required string Description { get; init; }
    public bool IsRequired { get; init; }
    public required IReadOnlyList<PlaybookOption> Options { get; init; }
}

/// <summary>Metadata parsed from the extracted playbook's playbook.conf.</summary>
public sealed class PlaybookManifest
{
    public string Name { get; init; } = "AkariOS";
    public string Title { get; init; } = "AkariOS";
    public string Version { get; init; } = "";
    public IReadOnlyList<string> SupportedBuilds { get; init; } = [];
    public IReadOnlyList<string> Requirements { get; init; } = [];
    public IReadOnlyList<PlaybookFeaturePage> FeaturePages { get; init; } = [];

    /// <summary>All currently-selected option names (what we pass to the CLI).</summary>
    public IEnumerable<string> SelectedOptions =>
        FeaturePages.SelectMany(p => p.Options).Where(o => o.IsSelected).Select(o => o.Name);

    // ----- parsing -----

    public static PlaybookManifest Parse(string playbookDir)
    {
        var confPath = Path.Combine(playbookDir, "playbook.conf");
        var xml = XDocument.Load(confPath).Root ?? throw new InvalidDataException("playbook.conf has no root element.");

        static string? El(XElement e, string name) => e.Element(name)?.Value.Trim();

        var featurePages = xml.Descendants("FeaturePages").Descendants("CheckboxPage")
            .Select(page => new PlaybookFeaturePage
            {
                Description = El(page, "Description") ?? "Options",
                IsRequired = bool.TryParse(El(page, "IsRequired"), out var req) && req,
                Options = page.Descendants("CheckboxOption")
                    .Select(o => PlaybookOption.Create(
                        El(o, "Name") ?? "",
                        El(o, "Text") ?? "",
                        bool.TryParse(El(o, "IsChecked"), out var c) && c))
                    .Where(o => o.Name.Length > 0)
                    .ToList(),
            })
            .Where(p => p.Options.Count > 0)
            .ToList();

        return new PlaybookManifest
        {
            Name = El(xml, "Name") ?? "AkariOS",
            Title = El(xml, "Title") ?? "AkariOS",
            Version = El(xml, "Version") ?? "",
            SupportedBuilds = xml.Descendants("SupportedBuilds").Descendants("string")
                .Select(s => s.Value.Trim()).Where(s => s.Length > 0).ToList(),
            Requirements = xml.Descendants("Requirements").Descendants("Requirement")
                .Select(s => s.Value.Trim()).Where(s => s.Length > 0).ToList(),
            FeaturePages = featurePages,
        };
    }
}
