using System.IO;

namespace AkariOS.Core.Tests;

/// <summary>The repo's folders, found from the test's output folder (linked into the App tests too).</summary>
internal static class Repo
{
    public static string Root { get; } = Find();

    public static string Src => Path.Combine(Root, "src");

    private static string Find()
    {
        for (var d = new DirectoryInfo(AppContext.BaseDirectory); d != null; d = d.Parent)
            if (File.Exists(Path.Combine(d.FullName, "AGENTS.md")) && Directory.Exists(Path.Combine(d.FullName, "src")))
                return d.FullName;
        throw new DirectoryNotFoundException("The repo root (AGENTS.md next to src/) was not found");
    }
}
