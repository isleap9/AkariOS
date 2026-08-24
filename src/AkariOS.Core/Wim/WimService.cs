using AkariOS.Core.Pipeline;
using ManagedWimLib;
using Microsoft.Extensions.Logging;
using WimLib = ManagedWimLib.Wim;

namespace AkariOS.Core.Wim;

/// <summary>One Windows edition inside a multi-image install.wim.</summary>
public sealed record WimImageInfo(int Index, string Name);

/// <summary>
/// Direct in-process WIM servicing via wimlib (ManagedWimLib): injects the payload into
/// \Windows\Setup\Scripts inside selected image indexes of sources\install.wim, so tweaks
/// are baked into the image itself — no DISM, no mounting.
/// </summary>
public sealed class WimService(ILogger<WimService>? logger = null)
{
    public const string WimRelativePath = @"sources\install.wim";
    private const string ScriptsWimPath = @"\Windows\Setup\Scripts";
    private const string NativeDllName = "libwim-15.dll";

    private static readonly object InitLock = new();
    private static bool _initialized;

    /// <summary>Initializes wimlib against the native dll bundled next to the app. Idempotent.</summary>
    public static void EnsureInitialized()
    {
        lock (InitLock)
        {
            if (_initialized) return;

            // ManagedWimLib.net copies runtimes\<rid>\native\libwim-15.dll into the output
            // tree; GlobalInit must be pointed at it explicitly (no default probing on Windows).
            var rid = Environment.Is64BitProcess ? "win-x64" : "win-x86";
            var candidate = Path.Combine(AppContext.BaseDirectory, "runtimes", rid, "native", NativeDllName);
            if (!File.Exists(candidate))
                candidate = Path.Combine(AppContext.BaseDirectory, NativeDllName);
            if (!File.Exists(candidate))
                throw new FileNotFoundException(
                    $"Native {NativeDllName} not found next to AkariOS.exe — it should ship with the app.", candidate);

            WimLib.GlobalInit(candidate);
            _initialized = true;
        }
    }

    /// <summary>Returns true if the staged tree carries a servable install.wim.</summary>
    public bool HasInstallWim(string stagingDirectory) =>
        File.Exists(Path.Combine(stagingDirectory, WimRelativePath));

    /// <summary>Lists editions (1-based index + name) without modifying anything.</summary>
    public IReadOnlyList<WimImageInfo> ListImages(string stagingDirectory)
    {
        EnsureInitialized();
        var wimPath = Path.Combine(stagingDirectory, WimRelativePath);
        using var wim = WimLib.OpenWim(wimPath, OpenFlags.None);
        var count = checked((int)wim.GetWimInfo().ImageCount);
        var result = new List<WimImageInfo>(count);
        for (var i = 1; i <= count; i++)
        {
            var name = wim.GetImageName(i);
            result.Add(new WimImageInfo(i, string.IsNullOrWhiteSpace(name) ? $"Image {i}" : name!));
        }
        return result;
    }

    /// <summary>
    /// Copies payload files into \Windows\Setup\Scripts of every selected index and writes
    /// the first-logon launcher hooks. Uses append-mode Overwrite: unchanged solid resources
    /// are NOT recompressed — this only appends the added files and updates the header.
    /// </summary>
    public void InjectPayload(string stagingDirectory, IReadOnlyList<string> payloadFiles,
        IReadOnlyList<int> indexes, IProgress<ProgressReport>? progress = null, CancellationToken ct = default)
    {
        if (indexes.Count == 0) return;
        EnsureInitialized();

        var wimPath = Path.Combine(stagingDirectory, WimRelativePath);
        // Files copied off mounted ISO media carry the read-only attribute; wimlib then
        // fails with [WimIsReadOnly] "Permission denied". Clear it before opening for write.
        ClearReadOnly(wimPath);
        // WriteAccess: required for Overwrite() to commit changes to the file.
        using var wim = WimLib.OpenWim(wimPath, OpenFlags.WriteAccess);

        // NOTE: wimlib reads file DATA at Write/Overwrite time, not at AddTree time —
        // these temp sources must stay alive until after the commit below.
        var payloadDir = TempDir.Create("wimpayload", payloadFiles);
        var hookDir = TempDir.CreateEmpty("wimhook");
        try
        {
            foreach (var index in indexes)
            {
                ct.ThrowIfCancellationRequested();
                var name = wim.GetImageName(index);
                progress?.Report(new ProgressReport(BuildStage.Injecting, null,
                    $"Servicing install.wim → edition {index} ({name ?? "?"})…"));
                logger?.LogInformation("Injecting {Count} payload files into install.wim index {Index} ({Name})",
                    payloadFiles.Count, index, name);

                // Files land in \Windows\Setup\Scripts inside the image — the same location
                // $OEM$\$$ would populate at setup time, now baked in permanently.
                wim.AddTree(index, payloadDir.Path, ScriptsWimPath, AddFlags.None);

                WriteHookFiles(hookDir.Path, payloadFiles);
                wim.AddTree(index, hookDir.Path, ScriptsWimPath, AddFlags.None);
            }

            ct.ThrowIfCancellationRequested();
            progress?.Report(new ProgressReport(BuildStage.Injecting, null, "Committing install.wim…"));
            // Rebuild: write to a temp file and rename over the original. Atomic + reliable
            // (append mode can fail on some media and leaves unusable holes behind).
            wim.Overwrite(WriteFlags.Rebuild, WimLib.DefaultThreads);
            logger?.LogInformation("install.wim committed");
        }
        finally
        {
            payloadDir.Dispose();
            hookDir.Dispose();
        }
    }

    /// <summary>
    /// Writes the first-logon trigger files. wimlib cannot edit registry hives offline, so we
    /// write a SetupComplete.cmd stub that registers the RunOnce entry at first boot — same
    /// trick as the $OEM$ path, applied offline inside the image.
    /// </summary>
    internal static void WriteHookFiles(string dir, IReadOnlyList<string> payloadFiles)
    {
        var ps1Names = payloadFiles.Select(Path.GetFileName)
            .Where(f => f?.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase) == true)
            .Select(f => f!);

        File.WriteAllText(Path.Combine(dir, Inject.OemInjectStep.LogonCmdFileName),
            Inject.OemInjectStep.LogonLauncherCommand(ps1Names));

        File.WriteAllText(Path.Combine(dir, Inject.OemInjectStep.BootstrapCmdFileName),
            "@echo off\r\nreg add \"HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce\" /v " +
            Inject.OemInjectStep.RunOnceValueName + " /t REG_SZ /d \"%WINDIR%\\Setup\\Scripts\\" +
            Inject.OemInjectStep.LogonCmdFileName + "\" /f >nul 2>&1\r\n");
    }

    /// <summary>Clears the read-only attribute so wimlib can open the WIM for writing.</summary>
    private static void ClearReadOnly(string path)
    {
        try
        {
            var attr = File.GetAttributes(path);
            if ((attr & FileAttributes.ReadOnly) != 0)
                File.SetAttributes(path, attr & ~FileAttributes.ReadOnly);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or FileNotFoundException)
        {
            // Opening the WIM will surface a clearer error than this would.
        }
    }

    /// <summary>Throwaway directory for building AddTree inputs.</summary>
    private sealed class TempDir : IDisposable
    {
        private TempDir(string path) => Path = path;

        public string Path { get; }

        public static TempDir Create(string tag, IReadOnlyList<string> copyFrom)
        {
            var dir = new TempDir(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "AkariOS", tag, System.IO.Path.GetRandomFileName()));
            Directory.CreateDirectory(dir.Path);
            foreach (var f in copyFrom)
                File.Copy(f, System.IO.Path.Combine(dir.Path, System.IO.Path.GetFileName(f)), overwrite: true);
            return dir;
        }

        public static TempDir CreateEmpty(string tag)
        {
            var dir = new TempDir(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "AkariOS", tag, System.IO.Path.GetRandomFileName()));
            Directory.CreateDirectory(dir.Path);
            return dir;
        }

        public void Dispose()
        {
            try { Directory.Delete(Path, recursive: true); }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { }
        }
    }
}
