namespace AkariOS.Core;

/// <summary>
/// Rule 12: nothing reaches the real system from a test. Every implementation that does (the live registry paths,
/// TrustedInstaller, services, boot settings...) calls <see cref="Check"/> when it is made; the test assemblies set
/// AKARI_UNDER_TEST=1 before any test runs, so making one there throws.
/// </summary>
public static class SystemGuard
{
    public const string Variable = "AKARI_UNDER_TEST";

    public static bool UnderTest => Environment.GetEnvironmentVariable(Variable) == "1";

    public static void Check(string what)
    {
        if (UnderTest) throw new InvalidOperationException($"{what} reaches the real system: tests must use a fake or the test registry key");
    }
}
