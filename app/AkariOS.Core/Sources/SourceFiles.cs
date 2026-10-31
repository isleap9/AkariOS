using System.Reflection;
using System.Text;

namespace AkariOS.Core.Sources;

/// <summary>
/// The src/ files the native app reads (Tweaks, data lists, presets, OneClick), by their src/ path with forward
/// slashes ("src/Tweaks/Optimize/Gaming/CaptureOff.ps1"): embedded in the exe in a release, the repo's folder in tests.
/// </summary>
public interface ISourceFiles
{
    /// <summary>Every path under the prefix ("src/Tweaks/"), in ordinal order.</summary>
    IReadOnlyList<string> List(string prefix);

    bool Exists(string path);

    byte[] ReadBytes(string path);
}

public static class SourceFilesExtensions
{
    /// <summary>The file as text: UTF-8 or UTF-16 by its BOM, else UTF-8.</summary>
    public static string ReadText(this ISourceFiles files, string path)
    {
        using var r = new StreamReader(new MemoryStream(files.ReadBytes(path)), Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
        return r.ReadToEnd();
    }

    /// <summary>"a/b/c.ps1" + "../d.psd1" style: a path next to another one (only plain names and '..').</summary>
    public static string Combine(string folder, string relative)
    {
        var parts = folder.TrimEnd('/').Split('/').ToList();
        foreach (var p in relative.Replace('\\', '/').Split('/'))
        {
            if (p is "" or ".") continue;
            if (p == "..") { if (parts.Count > 0) parts.RemoveAt(parts.Count - 1); continue; }
            parts.Add(p);
        }
        return string.Join('/', parts);
    }

    public static string Folder(string path) => path.LastIndexOf('/') is var i and >= 0 ? path[..i] : "";
}

/// <summary>The files embedded in AkariOS.Core (the release).</summary>
public sealed class EmbeddedSourceFiles : ISourceFiles
{
    private readonly Assembly _assembly = typeof(EmbeddedSourceFiles).Assembly;
    private readonly Dictionary<string, string> _names;

    public EmbeddedSourceFiles()
    {
        _names = _assembly.GetManifestResourceNames().ToDictionary(n => n.Replace('\\', '/'), n => n, StringComparer.OrdinalIgnoreCase);
    }

    public IReadOnlyList<string> List(string prefix) =>
        _names.Keys.Where(k => k.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)).Order(StringComparer.Ordinal).ToList();

    public bool Exists(string path) => _names.ContainsKey(path);

    public byte[] ReadBytes(string path)
    {
        if (!_names.TryGetValue(path, out var name)) throw new FileNotFoundException($"{path} is not embedded");
        using var s = _assembly.GetManifestResourceStream(name)!;
        using var m = new MemoryStream();
        s.CopyTo(m);
        return m.ToArray();
    }
}

/// <summary>A src/ folder on disk (tests, a developer's checkout). Root = the folder holding src/.</summary>
public sealed class FolderSourceFiles(string root) : ISourceFiles
{
    private string Full(string path) => Path.Combine(root, path.Replace('/', Path.DirectorySeparatorChar));

    public IReadOnlyList<string> List(string prefix)
    {
        var dir = Full(prefix.TrimEnd('/'));
        if (!Directory.Exists(dir)) return [];
        return Directory.GetFiles(dir, "*", SearchOption.AllDirectories)
            .Select(f => Path.GetRelativePath(root, f).Replace('\\', '/'))
            .Order(StringComparer.Ordinal).ToList();
    }

    public bool Exists(string path) => File.Exists(Full(path));

    public byte[] ReadBytes(string path) => File.ReadAllBytes(Full(path));
}

/// <summary>Files held in memory (tests).</summary>
public sealed class MemorySourceFiles : ISourceFiles
{
    private readonly SortedDictionary<string, byte[]> _files = new(StringComparer.Ordinal);

    public MemorySourceFiles Add(string path, string text)
    {
        _files[path] = Encoding.UTF8.GetBytes(text);
        return this;
    }

    public IReadOnlyList<string> List(string prefix) => _files.Keys.Where(k => k.StartsWith(prefix, StringComparison.Ordinal)).ToList();

    public bool Exists(string path) => _files.ContainsKey(path);

    public byte[] ReadBytes(string path) => _files.TryGetValue(path, out var b) ? b : throw new FileNotFoundException(path);
}
