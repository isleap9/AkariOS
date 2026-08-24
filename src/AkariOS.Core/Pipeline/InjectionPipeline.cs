using AkariOS.Core.Pipeline;
using Microsoft.Extensions.Logging;

namespace AkariOS.Core.Pipeline;

/// <summary>A single step of the injection pipeline.</summary>
public interface IBuildStep
{
    string Name { get; }

    Task ExecuteAsync(
        InjectionOptions options,
        BuildContext context,
        IProgress<ProgressReport> progress,
        CancellationToken cancellationToken);
}

/// <summary>State shared between pipeline steps.</summary>
public sealed class BuildContext
{
    /// <summary>Drive letter (with colon) of the mounted source ISO, set by the mount step.</summary>
    public string? MountedDrive { get; set; }

    /// <summary>Staging directory holding the editable ISO tree.</summary>
    public string? StagingDirectory { get; set; }

    /// <summary>Resolved output ISO path.</summary>
    public string? OutputIsoPath { get; set; }

    /// <summary>
    /// Optional per-build log sink for raw tool output (oscdimg, robocopy…).
    /// Set by <see cref="InjectionPipeline.RunAsync"/> when the caller supplies one.
    /// </summary>
    public Action<string>? Log { get; set; }

    public void WriteLog(string line)
    {
        if (Log is { } sink && !string.IsNullOrWhiteSpace(line))
            sink(line.TrimEnd());
    }

    public void ThrowIfCancellationRequested(CancellationToken ct) => ct.ThrowIfCancellationRequested();
}

/// <summary>Orchestrates build steps sequentially with progress and cancellation.</summary>
public sealed class InjectionPipeline
{
    private readonly IReadOnlyList<IBuildStep> _steps;
    private readonly ILogger<InjectionPipeline>? _logger;

    public InjectionPipeline(IEnumerable<IBuildStep> steps, ILogger<InjectionPipeline>? logger = null)
    {
        _steps = steps.ToList();
        _logger = logger;
    }

    public async Task<BuildResult> RunAsync(InjectionOptions options, IProgress<ProgressReport> progress, CancellationToken cancellationToken = default, Action<string>? log = null)
    {
        var context = new BuildContext { Log = log };
        try
        {
            foreach (var step in _steps)
            {
                cancellationToken.ThrowIfCancellationRequested();
                progress.Report(new ProgressReport(BuildStage.Validating, null, $"Starting: {step.Name}"));
                _logger?.LogInformation("Pipeline step {Step} starting", step.Name);
                await step.ExecuteAsync(options, context, progress, cancellationToken).ConfigureAwait(false);
            }
            progress.Report(new ProgressReport(BuildStage.Done, 100, "Build complete"));
            return new BuildResult(true, context.OutputIsoPath, null);
        }
        catch (OperationCanceledException)
        {
            return new BuildResult(false, null, "Build cancelled.");
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Pipeline failed");
            progress.Report(new ProgressReport(BuildStage.Cleanup, null, ex.Message, ProgressSeverity.Error));
            return new BuildResult(false, null, ex.Message);
        }
        finally
        {
            // Cleanup of staging/mounts is handled by dedicated cleanup steps registered last.
        }
    }
}
