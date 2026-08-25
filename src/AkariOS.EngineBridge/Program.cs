using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

// EngineBridge — tiny elevated helper (net472, no dependencies).
//
// Why: AkariOS (unelevated) cannot both elevate the CLI (runas) and capture its output
// (UseShellExecute=false disables Verb=runas). This bridge is launched elevated instead;
// being already elevated it starts the CLI with redirected pipes and mirrors every line
// to %TEMP%\AkariOS-Engine\out.txt so the UI can tail live progress while the CLI keeps
// its own console window.
//
// Usage: AkariOS.EngineBridge.exe <cliExePath> "<playbookDir>" [options...]
// Exit code = the CLI's exit code. The bridge writes "EXIT <code>" as the final line.

internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("usage: AkariOS.EngineBridge.exe <cliExe> <playbookDir> [options...]");
            return 2;
        }

        var cliExe = args[0];
        var playbookDir = args[1];
        var options = args.Skip(2);

        var outDir = Path.Combine(Path.GetTempPath(), "AkariOS-Engine");
        Directory.CreateDirectory(outDir);
        var outFile = Path.Combine(outDir, "out.txt");

        // Truncate at the start of each run.
        File.WriteAllText(outFile, string.Empty);

        var psi = new ProcessStartInfo
        {
            FileName = cliExe,
            Arguments = "\"" + playbookDir + "\" " + string.Join(" ", options.Select(o => "\"" + o + "\"")),
            WorkingDirectory = Path.GetDirectoryName(cliExe)!,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };

        using var cli = Process.Start(psi)!;
        using var writer = new StreamWriter(outFile, append: true) { AutoFlush = true };

        var outTask = PumpAsync(cli.StandardOutput, writer);
        var errTask = PumpAsync(cli.StandardError, writer);

        cli.WaitForExit();
        Task.WaitAll(new[] { outTask, errTask }, 10_000);

        writer.WriteLine("EXIT " + cli.ExitCode);
        return cli.ExitCode;
    }

    private static async Task PumpAsync(StreamReader reader, StreamWriter writer)
    {
        string line;
        while ((line = await reader.ReadLineAsync().ConfigureAwait(false)) != null)
            await writer.WriteLineAsync(line).ConfigureAwait(false);
    }
}
