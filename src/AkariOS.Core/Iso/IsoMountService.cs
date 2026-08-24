using System.Diagnostics;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace AkariOS.Core.Iso;

/// <summary>Mounts and dismounts ISO images via PowerShell's Mount-DiskImage.</summary>
public sealed partial class IsoMountService(ILogger<IsoMountService>? logger = null)
{
    /// <summary>Mounts the ISO at <paramref name="isoPath"/> and returns the drive letter (e.g. "E:").</summary>
    public async Task<string> MountAsync(string isoPath, CancellationToken cancellationToken = default)
    {
        if (!File.Exists(isoPath))
            throw new FileNotFoundException("ISO file not found.", isoPath);

        var result = await RunPowerShell(
            $"""
            $img = Mount-DiskImage -ImagePath '{Escape(isoPath)}' -PassThru
            ($img | Get-Volume).DriveLetter
            """, cancellationToken).ConfigureAwait(false);

        var letter = result.Trim().Trim('"');
        if (letter.Length != 2 || letter[1] != ':')
            throw new InvalidOperationException($"Failed to mount ISO '{isoPath}'. Mount-DiskImage returned: '{result}'");

        logger?.LogInformation("Mounted {Iso} as {Drive}", isoPath, letter);
        return letter;
    }

    /// <summary>Dismounts every disk image backed by <paramref name="isoPath"/>. Safe to call even when not mounted.</summary>
    public async Task DismountAsync(string isoPath, CancellationToken cancellationToken = default)
    {
        await RunPowerShell($"Dismount-DiskImage -ImagePath '{Escape(isoPath)}'", cancellationToken).ConfigureAwait(false);
        logger?.LogInformation("Dismounted {Iso}", isoPath);
    }

    private static string Escape(string path) => path.Replace("'", "''");

    private static async Task<string> RunPowerShell(string script, CancellationToken ct)
    {
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -NonInteractive -Command \"{script.Replace("\"", "\\\"")}\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        using var process = Process.Start(psi) ?? throw new InvalidOperationException("Failed to start powershell.exe");
        var stdout = await process.StandardOutput.ReadToEndAsync(ct).ConfigureAwait(false);
        await process.WaitForExitAsync(ct).ConfigureAwait(false);

        if (process.ExitCode != 0)
        {
            var stderr = await process.StandardError.ReadToEndAsync(ct).ConfigureAwait(false);
            throw new InvalidOperationException($"Mount-DiskImage failed (exit {process.ExitCode}): {stderr.Trim()}");
        }
        return stdout;
    }
}
