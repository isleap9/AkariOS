using AkariOS.Core.Registry;

namespace AkariOS.Tweaks;

/// <summary>Keys found under some roots at any depth (Get-ChildItem -Recurse), for Tweaks that walk every device.</summary>
public static class RegistryTree
{
    /// <summary>Every key under the roots (not the roots) whose own name matches, in walk order.</summary>
    public static IReadOnlyList<string> Find(RegistryEngine reg, IEnumerable<string> roots, Func<string, bool> name)
    {
        var found = new List<string>();
        void Walk(string path)
        {
            foreach (var k in reg.SubKeys(path))
            {
                var p = $@"{path}\{k}";
                if (name(k)) found.Add(p);
                Walk(p);
            }
        }
        foreach (var root in roots) Walk(root);
        return found;
    }

    /// <summary>Keys named exactly that (case aside).</summary>
    public static IReadOnlyList<string> Named(RegistryEngine reg, IEnumerable<string> roots, string name) =>
        Find(reg, roots, k => string.Equals(k, name, StringComparison.OrdinalIgnoreCase));

    /// <summary>A write that may be refused (a device key's permissions): skipped, as -ErrorAction SilentlyContinue did.</summary>
    public static void Try(Action write)
    {
        try { write(); }
        catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException) { }
    }
}
