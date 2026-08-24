using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Extensions.Logging;
using AkariOS.Core.Pipeline;

namespace AkariOS.Core.Iso;

/// <summary>
/// Rebuilds a bootable ISO from the staging tree using oscdimg (Windows ADK).
/// Locates oscdimg in this order: bundled next to the app → ADK install → user-configured path.
/// </summary>
public sealed class OscdimgService(ILogger<OscdimgService>? logger = null)
{
    /// <summary>Returns the path to a usable oscdimg.exe, or throws with actionable guidance.</summary>
    public string LocateOscdimg()
    {
        // 1) Bundled next to the app executable.
        var bundled = Path.Combine(AppContext.BaseDirectory, "tools", "oscdimg", "oscdimg.exe");
        if (File.Exists(bundled))
            return bundled;

        // 2) Windows ADK default install locations.
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"),
        };
        foreach (var baseDir in candidates.SelectMany(static d => new[] { "amd64", "x86" }, (d, arch) => Path.Combine(d, $"Oscdimg{arch}", "oscdimg.exe")))
        {
            if (File.Exists(baseDir))
                return baseDir;
        }

        throw new FileNotFoundException(
            "oscdimg.exe was not found. Place it at 'tools\\oscdimg\\oscdimg.exe' next to AkariOS.exe, " +
            "or install the Windows ADK Deployment Tools.");
    }

    /// <summary>Runs oscdimg to produce a dual-boot (BIOS+UEFI) ISO from <paramref name="stagingDirectory"/>.</summary>
    public async Task<string> BuildIsoAsync(string stagingDirectory, string outputIsoPath, CancellationToken ct)
    {
        var oscdimg = LocateOscdimg();
        Directory.CreateDirectory(Path.GetDirectoryName(outputIsoPath)!);

        var bootData =
            $"2#p0,e,b{stagingDirectory}\\boot\\etfsboot.com#pEF,e,b{stagingDirectory}\\efi\\microsoft\\boot\\efisys.bin";

        var psi = new ProcessStartInfo
        {
            FileName = oscdimg,
            Arguments = $"-m -o -u2 -udfver102 -bootdata:{bootData} \"{stagingDirectory}\" \"{outputIsoPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };

        logger?.LogInformation("Running oscdimg: {Args}", psi.Arguments);
        using var process = Process.Start(psi) ?? throw new InvalidOperationException("Failed to start oscdimg.exe");
        await process.WaitForExitAsync(ct).ConfigureAwait(false);

        if (process.ExitCode != 0 || !File.Exists(outputIsoPath))
            throw new IOException($"oscdimg failed (exit {process.ExitCode}): {await process.StandardError.ReadToEndAsync(ct).ConfigureAwait(false)}");

        return outputIsoPath;
    }
}

/// <summary>Pipeline step that rebuilds the ISO; sets <see cref="BuildContext.OutputIsoPath"/>.</summary>
public sealed class IsoRebuildStep(OscdimgService service) : IBuildStep
{
    public string Name => "Build AkariOS ISO";

    public async Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (context.StagingDirectory is null)
            throw new InvalidOperationException("No staging directory.");

        var output = options.OutputIsoPath ?? Path.Combine(
            Path.GetDirectoryName(options.SourceIsoPath)!,
            Path.GetFileNameWithoutExtension(options.SourceIsoPath) + "_AkariOS.iso");

        progress.Report(new ProgressReport(BuildStage.Rebuilding, 0, $"Building {Path.GetFileName(output)}…"));
        context.OutputIsoPath = await service.BuildIsoAsync(context.StagingDirectory, output, ct).ConfigureAwait(false);
        progress.Report(new ProgressReport(BuildStage.Rebuilding, 100, "ISO created."));
    }
}
