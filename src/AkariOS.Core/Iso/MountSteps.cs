using AkariOS.Core.Pipeline;

namespace AkariOS.Core.Iso;

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
