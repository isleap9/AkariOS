using AkariOS.Core.Pipeline;
using Microsoft.Extensions.Logging;

namespace AkariOS.Core.Wim;

/// <summary>
/// Pipeline step that services sources\install.wim directly (in addition to $OEM$ injection).
/// Runs after staging, before oscdimg. Skipped silently when no install.wim exists
/// (e.g. ESD-based media). Services ALL image indexes so every edition gets the tweaks.
/// </summary>
public sealed class WimServiceStep(WimService service, ILogger<WimServiceStep>? logger = null) : IBuildStep
{
    public string Name => "Bake tweaks into install.wim";

    public Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (context.StagingDirectory is null)
            throw new InvalidOperationException("No staging directory.");
        if (!service.HasInstallWim(context.StagingDirectory))
        {
            logger?.LogInformation("No install.wim in staged tree (ESD media?) — skipping WIM servicing");
            return Task.CompletedTask;
        }

        var images = service.ListImages(context.StagingDirectory);
        logger?.LogInformation("install.wim contains {Count} image(s): {Names}",
            images.Count, string.Join(", ", images.Select(i => i.Name)));

        // Service the user-selected editions; default = every edition on the media.
        var selected = options.SelectedImageIndexes is { Count: > 0 } picked
            ? images.Where(i => picked.Contains(i.Index)).ToList()
            : images;
        if (selected.Count == 0)
        {
            logger?.LogWarning("None of the selected indexes {Picked} exist in install.wim — servicing all editions instead",
                options.SelectedImageIndexes);
            selected = images;
        }

        service.InjectPayload(
            context.StagingDirectory,
            options.PayloadFiles,
            selected.Select(i => i.Index).ToList(),
            progress,
            ct);

        context.WriteLog($"> install.wim serviced ({string.Join(", ", selected.Select(i => i.Name))})");
        return Task.CompletedTask;
    }
}
