using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using Schneegans.Unattend;

namespace AkariOS.Core.Unattend;

/// <summary>This PC's display language, locale, keyboard, home location and time zone, as his field values
/// (Get-AkariUnattendDefaults); null = not read.</summary>
public sealed record PcRegion(string? UILanguage, string? Locale, string? Keyboard, string? GeoLocation, string? TimeZone);

/// <summary>Reads <see cref="PcRegion"/> (the real one reads this PC; tests fake it).</summary>
public interface IPcRegion
{
    PcRegion Read();
}

/// <summary>
/// The form's starting fields (UI\Unattend.ps1: Get-AkariUnattendStart): src/UI/Unattend.psd1's Defaults, the text
/// areas' samples (Get-AkariUnattendSamples), then this PC's language, region and time zone where his lists know them.
/// </summary>
public static class UnattendStart
{
    public const string SpecPath = "src/UI/Unattend.psd1";

    /// <summary>src/UI/Unattend.psd1: Sections (the form) and Defaults.</summary>
    public static PsHashtable Spec(ISourceFiles files) => (PsHashtable)PsData.Parse(files.ReadText(SpecPath)).Value!;

    public static Dictionary<string, string[]> Fields(ISourceFiles files, PcRegion pc)
    {
        var f = UnattendFields.New();
        foreach (var (k, v) in (PsHashtable)Spec(files).Get("Defaults")!) f[k] = Texts(v);
        foreach (var (k, v) in Samples(files)) f[k] = [v];
        var g = UnattendFile.His;
        void Known<T>(IReadOnlyDictionary<string, T> list, string field, string? id)
        {
            if (!string.IsNullOrEmpty(id) && list.Keys.Contains(id, StringComparer.OrdinalIgnoreCase)) f[field] = [id];
        }
        Known(g.ImageLanguages, "UILanguage", pc.UILanguage);
        Known(g.UserLocales, "Locale", pc.Locale);
        Known(g.KeyboardIdentifiers, "Keyboard", pc.Keyboard);
        Known(g.GeoLocations, "GeoLocation", pc.GeoLocation);
        Known(g.TimeOffsets, "TimeZone", pc.TimeZone);
        return f;
    }

    /// <summary>
    /// The text areas' starting text, as his page fills them. The literal ones are read out of src/Core/Unattend.ps1's
    /// Get-AkariUnattendSamples (not copied); the generated ones are his library's samples and his Wi-Fi profile.
    /// </summary>
    public static Dictionary<string, string> Samples(ISourceFiles files)
    {
        var text = files.ReadText("src/Core/Unattend.ps1");
        var fn = text.IndexOf("function Get-AkariUnattendSamples", StringComparison.Ordinal);
        var start = fn < 0 ? -1 : text.IndexOf("\n    @{", fn, StringComparison.Ordinal) + 1;
        var end = start <= 0 ? -1 : FunctionEnd(text, start);
        if (end < 0) throw new InvalidDataException("src/Core/Unattend.ps1 has no Get-AkariUnattendSamples hashtable");
        var table = (PsHashtable)PsData.Parse(text[start..end]).Value!;
        var samples = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var (k, v) in table)
            samples[k] = v is string s ? s : k switch
            {
                "TargetDiskScript" => Constants.SampleTargetDiskScript,
                "DiskpartScript" => Constants.SampleDiskpartScript,
                "PEScript" => Constants.SamplePEScript,
                "WifiProfileXml" => Resource("WLANProfile.xml"),
                _ => throw new InvalidDataException($"Get-AkariUnattendSamples: {k} is code the native app has no sample for"),
            };
        return samples;
    }

    /// <summary>Where the function's closing brace (a line holding only "}") starts, here-string bodies skipped
    /// (their lines start anywhere, '@ or "@ ends them); -1 when there is none.</summary>
    private static int FunctionEnd(string text, int from)
    {
        var inHere = false;
        for (var pos = from; pos < text.Length;)
        {
            var nl = text.IndexOf('\n', pos);
            var line = (nl < 0 ? text[pos..] : text[pos..nl]).TrimEnd('\r');
            if (inHere) inHere = !(line.StartsWith("'@") || line.StartsWith("\"@"));
            else if (line.EndsWith("@'") || line.EndsWith("@\"")) inHere = true;
            else if (line == "}") return pos;
            if (nl < 0) break;
            pos = nl + 1;
        }
        return -1;
    }

    /// <summary>One of his data files as text (Get-AkariUaResource: UTF-8, no BOM).</summary>
    public static string Resource(string name)
    {
        using var s = typeof(UnattendGenerator).Assembly.GetManifestResourceStream("Schneegans.Unattend.resource." + name)
            ?? throw new FileNotFoundException(name);
        using var r = new StreamReader(s, System.Text.Encoding.UTF8);
        return r.ReadToEnd().TrimStart('﻿');
    }

    private static string[] Texts(object? v) =>
        v is object?[] list ? [.. list.Select(x => PsSemantics.Text(x) ?? "")] : [PsSemantics.Text(v) ?? ""];
}
