namespace AkariOS.Tweaks.Tests.Apps;

/// <summary>One side's folders for the app tests (C# or PowerShell, each its own copy): %SystemRoot%, the program
/// folders, %ProgramData%, %PUBLIC%, the user's, the elevated account's %LOCALAPPDATA%.</summary>
internal sealed record AppRoots(string Windows, string ProgramFiles, string X86, string ProgramData, string Public, string User, string LocalAppData)
{
    public IEnumerable<(string Var, string Path)> All() =>
        [("%SystemRoot%", Windows), ("%ProgramFiles%", ProgramFiles), ("%ProgramFiles(x86)%", X86), ("%ProgramData%", ProgramData), ("%PUBLIC%", Public), ("%User%", User), ("%LOCALAPPDATA%", LocalAppData)];

    /// <summary>Makes the file (empty) under the root named by its first part ("%ProgramFiles(x86)%\…").</summary>
    public void Add(string file)
    {
        var (v, root) = All().First(r => file.StartsWith(r.Var + "\\", StringComparison.Ordinal));
        var p = Path.Combine(root, file[(v.Length + 1)..]);
        Directory.CreateDirectory(Path.GetDirectoryName(p)!);
        File.WriteAllText(p, "");
    }

    /// <summary>Every file and folder under the roots, as %Root%\….</summary>
    public List<string> Tree() => All().SelectMany(r => Directory.EnumerateFileSystemEntries(r.Path, "*", SearchOption.AllDirectories)
        .Select(e => r.Var + e[r.Path.Length..])).Order(StringComparer.OrdinalIgnoreCase).ToList();

    /// <summary>Every file's bytes as hex, by %Root%\… path.</summary>
    public List<string> Contents() => All().SelectMany(r => Directory.EnumerateFiles(r.Path, "*", SearchOption.AllDirectories)
        .Select(f => $"{r.Var}{f[r.Path.Length..]}={Convert.ToHexString(File.ReadAllBytes(f))}")).Order(StringComparer.OrdinalIgnoreCase).ToList();

    /// <summary>A text with these folders' paths written as %Root%.</summary>
    public string Vars(string text)
    {
        // longest first: Program Files (x86) before Program Files
        foreach (var (v, p) in All().OrderByDescending(r => r.Path.Length)) text = text.Replace(p, v, StringComparison.OrdinalIgnoreCase);
        return text;
    }
}
