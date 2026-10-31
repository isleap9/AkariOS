using System.Runtime.CompilerServices;

namespace AkariOS.App.Tests;

/// <summary>Rule 12: set before any test runs, so nothing that reaches the real system can be made here (SystemGuard).</summary>
internal static class UnderTest
{
    [ModuleInitializer]
    internal static void Start() => Environment.SetEnvironmentVariable(AkariOS.Core.SystemGuard.Variable, "1");
}
