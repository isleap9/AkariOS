using AkariOS.Core.Pipeline;

namespace AkariOS.Core.Inject;

/// <summary>
/// Injects the payload into the staged ISO tree under sources\$OEM$\$$\Setup\Scripts\.
/// Windows Setup copies $OEM$\$$ into C:\Windows during installation, so WinSux.ps1
/// and its SetupComplete.cmd trigger land in C:\Windows\Setup\Scripts on every install.
/// </summary>
public sealed class OemInjectStep : IBuildStep
{
    public const string ScriptsRelativePath = @"sources\$OEM$\$$\Setup\Scripts";
    public const string BootstrapCmdFileName = "SetupComplete.cmd";

    public string Name => "Inject AkariOS payload";

    public async Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
    {
        if (context.StagingDirectory is null)
            throw new InvalidOperationException("No staging directory.");

        var scriptsDir = Path.Combine(context.StagingDirectory, ScriptsRelativePath);
        Directory.CreateDirectory(scriptsDir);

        foreach (var file in options.PayloadFiles)
        {
            if (!File.Exists(file))
                throw new FileNotFoundException("Payload file missing.", file);
            File.Copy(file, Path.Combine(scriptsDir, Path.GetFileName(file)), overwrite: true);
        }

        // Merge our bootstrap line into SetupComplete.cmd (append if one already exists).
        var cmdPath = Path.Combine(scriptsDir, BootstrapCmdFileName);
        var line = BootstrapCommand(options.PayloadFiles.Select(Path.GetFileName).Where(f => f?.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase) == true)!);
        if (File.Exists(cmdPath) && File.ReadAllText(cmdPath).Contains("WinSux.ps1", StringComparison.Ordinal))
        {
            progress.Report(new ProgressReport(BuildStage.Injecting, null, "SetupComplete.cmd already contains the AkariOS hook.", ProgressSeverity.Warning));
        }
        else
        {
            await File.AppendAllTextAsync(cmdPath, line, ct);
        }

        progress.Report(new ProgressReport(BuildStage.Injecting, 50, $"Payload injected ({options.PayloadFiles.Count} files)."));
    }

    internal static string BootstrapCommand(IEnumerable<string> ps1FileNames)
    {
        var lines = ps1FileNames.Select(f =>
            $"powershell -NoProfile -ExecutionPolicy Bypass -File \"%WINDIR%\\Setup\\Scripts\\{f}\" >> \"%WINDIR%\\Setup\\Scripts\\AkariOS.log\" 2>&1");
        return Environment.NewLine + string.Join(Environment.NewLine, lines) + Environment.NewLine;
    }
}
