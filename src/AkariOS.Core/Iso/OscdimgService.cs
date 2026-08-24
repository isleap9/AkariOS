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
    private string? _externalPath;

    /// <summary>Registers an oscdimg path found by the acquisition service.</summary>
    public void SetExternalPath(string path) => _externalPath = path;

    /// <summary>True if a usable oscdimg exists (without acquiring).</summary>
    public bool CanLocate()
    {
        try { _ = LocateOscdimg(); return true; }
        catch (FileNotFoundException) { return false; }
    }

    /// <summary>Returns the path to a usable oscdimg.exe, or throws with actionable guidance.</summary>
    public string LocateOscdimg()
    {
        if (_externalPath is { } p && File.Exists(p))
            return p;

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

        // oscdimg refuses to overwrite an existing file — remove any previous output.
        // The old file may be briefly locked (AV scan, Explorer preview); retry a few times.
        if (File.Exists(outputIsoPath))
        {
            Exception? last = null;
            for (var attempt = 0; attempt < 5; attempt++)
            {
                try { File.Delete(outputIsoPath); last = null; break; }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                {
                    last = ex;
                    await Task.Delay(500, ct);
                }
            }
            if (last is not null)
                throw new IOException(
                    $"Cannot replace the previous output '{Path.GetFileName(outputIsoPath)}' — it is open in another program " +
                    "(close it, or eject the ISO if it's mounted, then try again).", last);
        }

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
        var stdoutTask = process.StandardOutput.ReadToEndAsync(ct);
        var stderrTask = process.StandardError.ReadToEndAsync(ct);
        await process.WaitForExitAsync(ct).ConfigureAwait(false);

        var stdout = await stdoutTask.ConfigureAwait(false);
        var stderr = await stderrTask.ConfigureAwait(false);

        if (process.ExitCode != 0 || !File.Exists(outputIsoPath))
            throw new IOException($"oscdimg failed (exit {process.ExitCode}): {stderr.Trim()} {stdout.Trim()}".Trim());

        return outputIsoPath;
    }
}

/// <summary>Pipeline step that ensures oscdimg exists, then rebuilds the ISO; sets <see cref="BuildContext.OutputIsoPath"/>.</summary>
public sealed class IsoRebuildStep(OscdimgService service, OscdimgAcquisitionService? acquisition = null) : IBuildStep
{
    public string Name => "Build AkariOS ISO";

    public async Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (context.StagingDirectory is null)
            throw new InvalidOperationException("No staging directory.");

        var output = options.OutputIsoPath ?? Path.Combine(
            Path.GetDirectoryName(options.SourceIsoPath) ?? Environment.CurrentDirectory,
            "AkariOS.iso");

        // Auto-acquire oscdimg on first use so users never see the ADK.
        if (!service.CanLocate() && acquisition is not null)
        {
            progress.Report(new ProgressReport(BuildStage.Rebuilding, 0, "First run: downloading the ISO creation tool from Microsoft…"));
            var path = await acquisition.AcquireAsync(
                new Progress<(int?, string)>(r => progress.Report(new ProgressReport(BuildStage.Rebuilding, r.Item1, r.Item2))),
                ct).ConfigureAwait(false);
            service.SetExternalPath(path);
        }

        progress.Report(new ProgressReport(BuildStage.Rebuilding, 0, $"Building {Path.GetFileName(output)}…"));
        context.OutputIsoPath = await service.BuildIsoAsync(context.StagingDirectory, output, ct).ConfigureAwait(false);
        progress.Report(new ProgressReport(BuildStage.Rebuilding, 100, "ISO created."));
    }
}
