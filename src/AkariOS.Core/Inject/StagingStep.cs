using AkariOS.Core.Pipeline;

namespace AkariOS.Core.Inject;

/// <summary>Copies the ISO tree to an editable staging folder; sets <see cref="BuildContext.StagingDirectory"/>.</summary>
public sealed class StagingStep : IBuildStep
{
    public string Name => "Stage ISO contents";

    public Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
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
        process.WaitForExit();
        if (process.ExitCode > 7)
            throw new IOException($"robocopy failed with exit code {process.ExitCode} while staging the ISO.");

        context.StagingDirectory = staging;
        return Task.CompletedTask;
    }
}

/// <summary>Deletes the staging directory. Registered as a cleanup step.</summary>
public sealed class StagingCleanupStep : IBuildStep
{
    public string Name => "Cleanup staging";

    public Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (context.StagingDirectory is { } dir && Directory.Exists(dir))
        {
            try { Directory.Delete(dir, recursive: true); }
            catch (IOException)
            {
                progress.Report(new ProgressReport(BuildStage.Cleanup, null, $"Could not delete temp folder '{dir}'. You can remove it manually.", ProgressSeverity.Warning));
            }
        }
        return Task.CompletedTask;
    }
}
