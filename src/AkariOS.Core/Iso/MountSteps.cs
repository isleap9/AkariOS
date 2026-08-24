using AkariOS.Core.Pipeline;

namespace AkariOS.Core.Iso;

/// <summary>Validates the source ISO and available disk space before mounting.</summary>
public sealed class ValidationStep : IBuildStep
{
    /// <summary>Staging (~10 GB) + output ISO (~10 GB) + headroom. Conservative: assumes the output may be slightly larger than the source.</summary>
    private const long RequiredBytes = 25L * 1024 * 1024 * 1024;

    public string Name => "Validate";

    public Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (!File.Exists(options.SourceIsoPath))
            throw new FileNotFoundException("ISO file not found.", options.SourceIsoPath);

        var isoSize = new FileInfo(options.SourceIsoPath).Length;
        var drive = Path.GetPathRoot(Path.GetFullPath(options.OutputIsoPath ?? options.SourceIsoPath))
            ?? throw new InvalidOperationException("Cannot determine output drive.");
        var free = new DriveInfo(drive).AvailableFreeSpace;

        // Needed: staging copy + the output ISO itself.
        var needed = isoSize + RequiredBytes;
        if (free < needed)
        {
            throw new IOException(
                $"Not enough disk space on {drive} — needs about {(needed / 1024d / 1024 / 1024):F0} GB " +
                $"(staged copy + output ISO), only {(free / 1024d / 1024 / 1024):F0} GB free.");
        }

        return Task.CompletedTask;
    }
}

/// <summary>Validates the ISO and mounts it; sets <see cref="BuildContext.MountedDrive"/>.</summary>
public sealed class MountStep(IsoMountService mountService) : IBuildStep
{
    public string Name => "Mount ISO";

    public async Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (!File.Exists(options.SourceIsoPath))
            throw new FileNotFoundException("ISO file not found.", options.SourceIsoPath);

        progress.Report(new ProgressReport(BuildStage.Mounting, null, $"Mounting {Path.GetFileName(options.SourceIsoPath)}…"));
        var drive = await mountService.MountAsync(options.SourceIsoPath, ct).ConfigureAwait(false);

        // Sanity-check it is a Windows install medium.
        if (!Directory.Exists(Path.Combine(drive + Path.DirectorySeparatorChar.ToString(), "sources")))
        {
            await mountService.DismountAsync(options.SourceIsoPath, ct).ConfigureAwait(false);
            throw new InvalidOperationException("The mounted image does not look like a Windows installation ISO (no 'sources' folder).");
        }

        context.MountedDrive = drive;
    }
}

/// <summary>Dismounts the source ISO if still mounted. Always registered as a cleanup step.</summary>
public sealed class DismountStep(IsoMountService mountService) : IBuildStep
{
    public string Name => "Dismount ISO";

    public Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        try
        {
            return mountService.DismountAsync(options.SourceIsoPath, ct);
        }
        catch
        {
            // Best-effort cleanup; a leaked mount is not worth failing the build over,
            // but warn so users can eject manually.
            progress.Report(new ProgressReport(BuildStage.Cleanup, null, "Could not dismount the ISO automatically — you can eject it manually.", ProgressSeverity.Warning));
            return Task.CompletedTask;
        }
    }
}
