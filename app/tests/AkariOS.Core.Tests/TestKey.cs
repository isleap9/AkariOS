using AkariOS.Core.Registry;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

/// <summary>
/// A test registry key, HKCU\Software\AkariTest\&lt;guid&gt;, deleted afterwards (rule 12): every hive a row names is
/// redirected under it (HKLM:\X = ...\&lt;guid&gt;\HKLM\X).
/// </summary>
public sealed class TestKey : IDisposable
{
    public string Root { get; } = $@"Software\AkariTest\{Guid.NewGuid():N}";

    public RedirectedRegistryPaths Paths => new(Root);

    /// <summary>The real HKCU path a redirected row lands on (for the PowerShell side of a test).</summary>
    public string Real(string hive, string sub) => $@"HKCU:\{Root}\{hive}\{sub}";

    public void Dispose()
    {
        using var hkcu = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64);
        hkcu.DeleteSubKeyTree(Root, throwOnMissingSubKey: false);
    }
}
