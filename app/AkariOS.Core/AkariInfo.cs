using System.Reflection;

namespace AkariOS.Core;

/// <summary>What the app is: its version (the PowerShell app's $AkariVersion, read at build time).</summary>
public static class AkariInfo
{
    public static string Version { get; } =
        typeof(AkariInfo).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0.0.0";

    /// <summary>Not a published single-file exe (dotnet build's output, run from bin\): it can't replace or copy itself.
    /// A WinUI single-file publish unpacks its assemblies to %TEMP%\.net\… (the Windows App SDK forces
    /// IncludeAllContentForSelfExtract), so its Location isn't empty: what tells them apart is whether the assembly sits
    /// beside the exe.</summary>
    // IL3000: an empty Location (a plain single-file publish) is one of the answers read here
#pragma warning disable IL3000
    public static bool IsDeveloperBuild() => IsDeveloperBuild(typeof(AkariInfo).Assembly.Location, Environment.ProcessPath);
#pragma warning restore IL3000

    /// <summary>Pure: the engine assembly's file and the running exe.</summary>
    public static bool IsDeveloperBuild(string? assemblyLocation, string? processPath) =>
        !string.IsNullOrEmpty(assemblyLocation) && !string.IsNullOrEmpty(processPath) &&
        string.Equals(Path.GetDirectoryName(Path.GetFullPath(assemblyLocation)), Path.GetDirectoryName(Path.GetFullPath(processPath)),
            StringComparison.OrdinalIgnoreCase);

    /// <summary>The src/ files embedded in the engine, by their src/ path with forward slashes.</summary>
    public static IReadOnlyList<string> EmbeddedPaths() =>
        typeof(AkariInfo).Assembly.GetManifestResourceNames().Select(n => n.Replace('\\', '/')).Order(StringComparer.Ordinal).ToList();
}
