using System.Reflection;

namespace AkariOS.Core;

/// <summary>What the app is: its version (the PowerShell app's $AkariVersion, read at build time).</summary>
public static class AkariInfo
{
    public static string Version { get; } =
        typeof(AkariInfo).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0.0.0";

    /// <summary>The src/ files embedded in the engine, by their src/ path with forward slashes.</summary>
    public static IReadOnlyList<string> EmbeddedPaths() =>
        typeof(AkariInfo).Assembly.GetManifestResourceNames().Select(n => n.Replace('\\', '/')).Order(StringComparer.Ordinal).ToList();
}
