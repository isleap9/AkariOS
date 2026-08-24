using System.Diagnostics;
using System.Security.Cryptography;
using Microsoft.Extensions.Logging;

namespace AkariOS.Core.Iso;

/// <summary>
/// Ensures oscdimg.exe is available, downloading the Oscdimg component from Microsoft's
/// official ADK when missing. Downloads go to %LOCALAPPDATA%\AkariOS\tools\oscdimg.
/// </summary>
public sealed partial class OscdimgAcquisitionService(ILogger<OscdimgAcquisitionService>? logger = null)
{
    // Official ADK fwlink (Windows 11 ADK); /layout pulls only requested feature cabs.
    private const string AdkFwLink = "https://go.microsoft.com/fwlink/?linkid=2271337";

    private static string ToolsDir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "AkariOS", "tools", "oscdimg");

    public string ExpectedOscdimgPath => Path.Combine(ToolsDir, "oscdimg.exe");

    /// <summary>True if a usable oscdimg already exists anywhere we look.</summary>
    public bool IsAvailable() => LocateAny().Success;

    /// <summary>Finds an existing oscdimg: app-local → our tools dir → installed ADK.</summary>
    public (bool Success, string? Path, string? Message) LocateAny()
    {
        var bundled = Path.Combine(AppContext.BaseDirectory, "tools", "oscdimg", "oscdimg.exe");
        if (File.Exists(bundled)) return (true, bundled, null);
        if (File.Exists(ExpectedOscdimgPath)) return (true, ExpectedOscdimgPath, null);

        foreach (var arch in new[] { "amd64", "x86" })
        {
            var adk = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                "Windows Kits", "10", "Assessment and Deployment Kit", "Deployment Tools",
                arch, "Oscdimg", "oscdimg.exe");
            if (File.Exists(adk)) return (true, adk, null);
        }
        return (false, null, "oscdimg.exe not found.");
    }

    /// <summary>
    /// Downloads the ADK bootstrapper and lays out just the DeploymentTools cabs,
    /// then installs the Oscdimg MSI into our tools dir. Returns path to oscdimg.exe.
    /// </summary>
    public async Task<string> AcquireAsync(IProgress<(int? Percent, string Message)> progress, CancellationToken ct)
    {
        Directory.CreateDirectory(ToolsDir);

        // Step 1: download ADK setup (small bootstrapper).
        var setupPath = Path.Combine(Path.GetTempPath(), "AkariOS-adksetup.exe");
        progress.Report((10, "Downloading Windows ADK setup…"));
        await DownloadAsync(AdkFwLink, setupPath, new Progress<double>(p => progress.Report(((int)(p * 0.3), $"Downloading ADK setup… {p:P0}"))), ct);

        // Step 2: layout the ADK cabs. NOTE: adksetup rejects /features in layout mode
        // ("Selecting features for download is not allowed"), so we must download all
        // cabs (~2 GB) and pick the Oscdimg MSI from the result.
        progress.Report((35, "Downloading oscdimg component (ADK layout)…"));
        var layoutDir = Path.Combine(Path.GetTempPath(), "AkariOS-adk");
        if (Directory.Exists(layoutDir)) Directory.Delete(layoutDir, true);
        Directory.CreateDirectory(layoutDir);

        var psi = new ProcessStartInfo
        {
            FileName = setupPath,
            Arguments = $"/quiet /layout \"{layoutDir}\"",
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        using (var setup = Process.Start(psi) ?? throw new InvalidOperationException("Failed to start adksetup.exe"))
        {
            await setup.WaitForExitAsync(ct);
            if (setup.ExitCode != 0)
                throw new IOException($"ADK download failed with exit code {setup.ExitCode}.");
        }

        // Step 3: find + run the Oscdimg MSI silently into our tools dir.
        progress.Report((80, "Installing oscdimg…"));
        var msi = Directory.EnumerateFiles(layoutDir, "*Oscdimg*.msi", SearchOption.AllDirectories).FirstOrDefault()
            ?? throw new FileNotFoundException("Oscdimg component not found in downloaded ADK.");

        var msiPsi = new ProcessStartInfo
        {
            FileName = "msiexec.exe",
            Arguments = $"/i \"{msi}\" /quiet INSTALLDIR=\"{ToolsDir}\"",
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        using (var msiProc = Process.Start(msiPsi) ?? throw new InvalidOperationException("Failed to start msiexec"))
        {
            await msiProc.WaitForExitAsync(ct);
            if (msiProc.ExitCode != 0)
                throw new IOException($"oscdimg install failed with exit code {msiProc.ExitCode}.");
        }

        if (!File.Exists(ExpectedOscdimgPath))
            throw new FileNotFoundException($"Installed but oscdimg.exe not at expected location ({ExpectedOscdimgPath}).");

        logger?.LogInformation("oscdimg acquired at {Path}", ExpectedOscdimgPath);
        progress.Report((100, "oscdimg ready."));
        return ExpectedOscdimgPath;
    }

    private static async Task DownloadAsync(string url, string destFile, IProgress<double> progress, CancellationToken ct)
    {
        using var http = new HttpClient();
        using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
        response.EnsureSuccessStatusCode();

        var total = response.Content.Headers.ContentLength ?? -1;
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        await using var file = File.Create(destFile);

        var buffer = new byte[81920];
        long read = 0;
        int n;
        while ((n = await stream.ReadAsync(buffer, ct)) > 0)
        {
            await file.WriteAsync(buffer.AsMemory(0, n), ct);
            read += n;
            if (total > 0) progress.Report((double)read / total);
        }
    }
}
