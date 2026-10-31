using System.IO;

namespace AkariOS.App;

/// <summary>The command line of AkariOS-Native.exe. N0: --version only; --list, --apply and the rest come in N1.</summary>
public static class Cli
{
    /// <summary>True when the arguments ask for the console instead of the window.</summary>
    public static bool IsCli(string[] args) => args.Length > 0;

    /// <summary>Runs a command and returns the exit code.</summary>
    public static int Run(string[] args, TextWriter output)
    {
        switch (args[0].ToLowerInvariant())
        {
            case "--version":
                output.WriteLine($"AkariOS-Native {Core.AkariInfo.Version}");
                return 0;
            default:
                output.WriteLine($"Unknown option '{args[0]}'. Options: --version");
                return 1;
        }
    }
}
