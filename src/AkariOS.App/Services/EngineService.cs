using System.Diagnostics;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace AkariOS.App.Services;

/// <summary>Result of one engine (CLI) run.</summary>
public sealed record EngineRunResult(int ExitCode, bool Cancelled);

/// <summary>
/// Owns the bundled AME Wizard Core CLI (TrustedUninstaller.CLI.exe): launches it elevated
/// on demand, streams its console output into a log sink, and parses the well-known
/// "&lt;pct&gt;% &lt;status&gt;..." lines into progress reports.
///
/// The CLI is always launched with explicit options — never zero — because the upstream
/// 0.8.4 release crashes with SerializationException when options are empty
/// (InterLink.GetParameters cannot serialize a null string[]).
/// </summary>
public sealed partial class EngineService(ILogger<EngineService>? logger = null)
{
    /// <summary>Directory containing TrustedUninstaller.CLI.exe and its dependencies.</summary>
    private static string CliDir =>
        Path.Combine(AppContext.BaseDirectory, "engine");

    private static string CliExe => Path.Combine(CliDir, "TrustedUninstaller.CLI.exe");

    /// <summary>Extracted playbook folder used for runs (created on demand).</summary>
    public static string PlaybookWorkDir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AkariOS", "playbook");

    /// <summary>Bundled playbook archive shipped with the app.</summary>
    public static string BundledPlaybookPath =>
        Path.Combine(AppContext.BaseDirectory, "assets", "AkariOS-Playbook.apbx");

    /// <summary>True if the engine payload is present and looks usable.</summary>
    public static bool IsEnginePresent() => File.Exists(CliExe);

    [GeneratedRegex(@"^\s*(\d{1,3})%\s*(.*)$")]
    private static partial Regex ProgressLineRegex();

    /// <summary>
    /// Runs the playbook. <paramref name="showConsole"/> keeps the CLI's own window visible
    /// (debugging); when false the console is hidden and stdout is captured for parsing.
    ///
    /// NOTE: with a visible console we CANNOT capture stdout (two owners of one pipe), so
    /// progress reporting only works in hidden mode. Visible mode = debugging, no parse.
    /// </summary>
    public async Task<EngineRunResult> RunPlaybookAsync(
        IReadOnlyList<string> options,
        Action<int, string>? onProgress,
        Action<string>? onLogLine,
        bool showConsole,
        CancellationToken ct)
    {
        if (!IsEnginePresent())
            throw new FileNotFoundException(
                "The AkariOS engine is missing (engine\\TrustedUninstaller.CLI.exe next to the app).", CliExe);

        var playbookDir = EnsurePlaybookExtracted();

        // Never pass an empty option list — upstream 0.8.4 crashes on null/empty string[]
        // (SerializationException in InterLink.GetParameters). 'akariserv' ships ticked by default.
        if (options.Count == 0) options = ["akariserv"];

        var psi = new ProcessStartInfo
        {
            FileName = CliExe,
            Arguments = $"\"{playbookDir}\" {string.Join(" ", options.Select(a => $"\"{a}\""))}",
            WorkingDirectory = CliDir,
            UseShellExecute = true,   // required for Verb=runas
            Verb = "runas",           // single UAC prompt at engine start
            CreateNoWindow = !showConsole,
        };

        // Hidden mode: capture output so we can parse progress.
        if (!showConsole)
        {
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.UseShellExecute = false;  // incompatible with redirect; runas no longer applies!
            // NOTE: UseShellExecute=false means no Verb=runas → the child inherits our token.
            // A hidden+elevated launch needs either an elevated helper or app-compat flag;
            // for now hidden mode requires AkariOS itself to be running elevated.
        }

        logger?.LogInformation("Launching engine: {Exe} {Args} (console={Show})", CliExe, psi.Arguments, showConsole);

        using var process = new Process { StartInfo = psi };
        try
        {
            process.Start();
        }
        catch (System.ComponentModel.Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            logger?.LogInformation("User declined the UAC prompt.");
            return new EngineRunResult(-1, Cancelled: true);
        }

        if (showConsole)
        {
            await process.WaitForExitAsync(ct).ConfigureAwait(false);
            return new EngineRunResult(process.ExitCode, Cancelled: ct.IsCancellationRequested);
        }

        // ---- hidden mode: pump + parse ------------------------------------
        var progressRegex = ProgressLineRegex();
        void Pump(string? line)
        {
            if (string.IsNullOrWhiteSpace(line)) return;
            onLogLine?.Invoke(line);
            var m = line.Length <= 200 ? progressRegex.Match(line) : Match.Empty;
            if (m.Success)
                onProgress?.Invoke(
                    int.Parse(m.Groups[1].Value),
                    m.Groups[2].Value.TrimEnd('.', ' ').Trim());
        }

        var outTask = process.StandardOutput.ReadLineLoopAsync(l => Pump(l), ct);
        var errTask = process.StandardError.ReadLineLoopAsync(l => Pump(l), ct);

        await process.WaitForExitAsync(ct).ConfigureAwait(false);
        try { await Task.WhenAll(outTask, errTask).ConfigureAwait(false); } catch { /* cancelled */ }

        return new EngineRunResult(process.ExitCode, Cancelled: ct.IsCancellationRequested);
    }

    /// <summary>Extracts the bundled .apbx over the work dir (idempotent, version-stamped).</summary>
    private string EnsurePlaybookExtracted()
    {
        var dir = PlaybookWorkDir;
        if (Directory.Exists(dir) && File.Exists(Path.Combine(dir, "playbook.conf")))
        {
            // Already extracted; real version-stamp logic lands with self-update.
            return dir;
        }

        if (!File.Exists(BundledPlaybookPath))
            throw new FileNotFoundException("Bundled AkariOS playbook not found.", BundledPlaybookPath);

        Directory.CreateDirectory(dir);
        RunSevenZip($"x \"{BundledPlaybookPath}\" -o\"{dir}\" -pmalte -y");
        logger?.LogInformation("Playbook extracted to {Dir}", dir);
        return dir;
    }

    private static void RunSevenZip(string args)
    {
        // CLI-Standalone ships 7za.exe (standalone console build); accept plain 7z.exe too.
        var sevenZip = new[] { "7za.exe", "7z.exe" }
            .Select(n => Path.Combine(AppContext.BaseDirectory, "engine", n))
            .FirstOrDefault(File.Exists)
        ?? throw new FileNotFoundException(
            "Neither engine\\7za.exe nor engine\\7z.exe was found next to the app — needed to extract the playbook.");

        using var p = Process.Start(new ProcessStartInfo
        {
            FileName = sevenZip,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = true,
        })!;
        p.WaitForExit(120_000);
        if (p.HasExited && p.ExitCode != 0)
            throw new IOException($"7-Zip failed extracting the playbook (exit {p.ExitCode}).");
    }
}

internal static class ProcessLineReaderExtensions
{
    public static async Task ReadLineLoopAsync(this StreamReader reader, Action<string> onLine, CancellationToken ct)
    {
        while (await reader.ReadLineAsync(ct).ConfigureAwait(false) is { } line)
            onLine(line);
    }
}
