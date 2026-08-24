using AkariOS.Core.Pipeline;
using Microsoft.Extensions.Logging;

namespace AkariOS.Core.Inject;

/// <summary>Copies the ISO tree to an editable staging folder; sets <see cref="BuildContext.StagingDirectory"/>.</summary>
public sealed class StagingStep : IBuildStep
{
    public string Name => "Stage ISO contents";

    public async Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(context.MountedDrive))
            throw new InvalidOperationException("ISO is not mounted.");

        var staging = options.WorkingDirectory is null
            ? Path.Combine(Path.GetTempPath(), "AkariOS", Path.GetRandomFileName())
            : Path.Combine(options.WorkingDirectory, "staging");

        Directory.CreateDirectory(staging);

        // Robocopy: /E all subdirs incl. empty, /NFL/NDL quiet, /NP no per-file progress.
        // Exit codes 0-7 are success for robocopy.
        var psi = new System.Diagnostics.ProcessStartInfo
        {
            FileName = "robocopy.exe",
            Arguments = $"\"{context.MountedDrive}\" \"{staging}\" /E /R:2 /W:2 /NFL /NDL /NP",
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        progress.Report(new ProgressReport(BuildStage.Staging, null, "Copying ISO contents…"));
        using var process = System.Diagnostics.Process.Start(psi)!;
        try
        {
            await process.WaitForExitAsync(ct).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            // Cancel must actually stop the copy: kill robocopy, then rethrow so
            // the pipeline reports "cancelled" instead of waiting it out.
            TryKill(process);
            throw;
        }
        if (process.ExitCode > 7)
            throw new IOException($"robocopy failed with exit code {process.ExitCode} while staging the ISO.");

        context.StagingDirectory = staging;
    }

    private static void TryKill(System.Diagnostics.Process process)
    {
        try { if (!process.HasExited) process.Kill(entireProcessTree: true); }
        catch (InvalidOperationException) { /* already exited */ }
        catch (System.ComponentModel.Win32Exception) { /* access denied — best effort */ }
    }
}

/// <summary>Deletes the staging directory. Registered as a cleanup step.</summary>
public sealed class StagingCleanupStep : IBuildStep
{
    public string Name => "Cleanup staging";

    /// <summary>Also removes staging folders leaked by earlier failed runs (crash/kill leaves ~10 GB each).</summary>
    internal static void SweepStaleTempFolders(ILogger? logger = null)
    {
        var root = Path.Combine(Path.GetTempPath(), "AkariOS");
        if (!Directory.Exists(root)) return;
        foreach (var dir in Directory.EnumerateDirectories(root))
        {
            try { Directory.Delete(dir, recursive: true); }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                logger?.LogWarning(ex, "Could not delete stale staging dir {Dir}", dir);
            }
        }
    }

    public Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (context.StagingDirectory is { } dir && Directory.Exists(dir))
        {
            try
            {
                // Robocopy preserves read-only attributes (e.g. autorun.inf); clear them so delete works.
                foreach (var f in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories))
                {
                    var attr = File.GetAttributes(f);
                    if ((attr & FileAttributes.ReadOnly) != 0)
                        File.SetAttributes(f, attr & ~FileAttributes.ReadOnly);
                }
                Directory.Delete(dir, recursive: true);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                progress.Report(new ProgressReport(BuildStage.Cleanup, null, $"Could not delete temp folder '{dir}'. You can remove it manually.", ProgressSeverity.Warning));
            }
        }
        return Task.CompletedTask;
    }
}
