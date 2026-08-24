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
    public const string LogonCmdFileName = "AkariOSWinSux.cmd";
    public const string RunOnceValueName = "AkariOS_WinSux";

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

        // SetupComplete.cmd runs BEFORE the user ever sees the desktop, and Windows
        // blocks OOBE until it exits — running WinSux there makes the install appear
        // to hang. Instead we only write a tiny launcher cmd and register it as a
        // RunOnce entry, so WinSux fires right after the first logon, once the user
        // is actually on the desktop.
        var cmdPath = Path.Combine(scriptsDir, BootstrapCmdFileName);
        if (File.Exists(cmdPath) && File.ReadAllText(cmdPath).Contains(RunOnceValueName, StringComparison.Ordinal))
        {
            progress.Report(new ProgressReport(BuildStage.Injecting, null, "SetupComplete.cmd already contains the AkariOS hook.", ProgressSeverity.Warning));
        }
        else
        {
            await File.AppendAllTextAsync(cmdPath, BootstrapCommand(), ct);
        }

        // The actual launcher: waits a moment for the desktop to settle, then runs WinSux.
        var ps1Names = options.PayloadFiles.Select(Path.GetFileName)
            .Where(f => f?.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase) == true)
            .Select(f => f!);
        var logonCmd = Path.Combine(scriptsDir, LogonCmdFileName);
        await File.WriteAllTextAsync(logonCmd, LogonLauncherCommand(ps1Names), ct);

        progress.Report(new ProgressReport(BuildStage.Injecting, 50, $"Payload injected ({options.PayloadFiles.Count} files)."));
    }

    /// <summary>
    /// SetupComplete.cmd body: near-instant. Registers a RunOnce entry so WinSux
    /// launches on first logon (desktop visible), instead of blocking OOBE.
    /// </summary>
    internal static string BootstrapCommand()
    {
        return Environment.NewLine +
            "reg add \"HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce\" /v " + RunOnceValueName +
            " /t REG_SZ /d \"%WINDIR%\\Setup\\Scripts\\" + LogonCmdFileName + "\" /f >nul 2>&1" +
            Environment.NewLine;
    }

    /// <summary>
    /// Launcher executed at first interactive logon: gives the desktop a moment to
    /// settle, then runs each payload ps1 and logs output.
    /// </summary>
    internal static string LogonLauncherCommand(IEnumerable<string> ps1FileNames)
    {
        var lines = new List<string>
        {
            "@echo off",
            "timeout /t 10 /nobreak >nul"
        };
        lines.AddRange(ps1FileNames.Select(f =>
            $"powershell -NoProfile -ExecutionPolicy Bypass -File \"%WINDIR%\\Setup\\Scripts\\{f}\" >> \"%WINDIR%\\Setup\\Scripts\\AkariOS.log\" 2>&1"));
        return string.Join(Environment.NewLine, lines) + Environment.NewLine;
    }
}
