using System.Diagnostics;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;

namespace AkariOS.Core.Apps;

/// <summary>What winget.exe did: its exit code and output lines.</summary>
public sealed record WingetResult(int Code, IReadOnlyList<string> Output);

/// <summary>winget.exe (Invoke-AkariWinget): runs it and waits; throws when winget is not on the PC.</summary>
public interface IWinget
{
    WingetResult Run(params string[] arguments);
}

/// <summary>
/// The engine side of a Tweak's Winget field and the Store restores (src/Core/Winget.ps1): a working winget first
/// (App Installer registered again, else installed from Microsoft's winget-cli release), the Microsoft Store for
/// msstore installs (registered again, else from winget, else Windows' own reinstall), then a silent install.
/// </summary>
public sealed class Winget(IWinget winget, IPackageManager packages, IHttp http, AppPackages apps, IExe? exe, IAkariLog log,
    string tempFolder, string windowsFolder, Action<TimeSpan> sleep)
{
    /// <summary>$AkariWingetMin: --disable-interactivity and reliable exit codes.</summary>
    public static readonly Version Min = new(1, 6, 0);

    /// <summary>$AkariWingetOk: 0, PACKAGE_ALREADY_INSTALLED, UPDATE_NOT_APPLICABLE.</summary>
    public static IReadOnlyList<int> Ok { get; } = [0, -1978335135, -1978335189];

    public const string AppInstallerFamily = "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe";
    public const string StoreProductId = "9WZDNCRFJBMP";
    public const string StorePackage = "Microsoft.WindowsStore";
    private const string Release = "https://github.com/microsoft/winget-cli/releases/latest/download";
    private static readonly string[] Flags = ["--silent", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity"];

    private bool _ready;

    /// <summary>Get-AkariWingetVersion: the first line of --version; null when winget isn't there or says nonsense.</summary>
    public Version? ToolVersion()
    {
        WingetResult r;
        try { r = winget.Run("--version"); } catch (Exception) { return null; }
        var v = Regex.Replace((r.Output.FirstOrDefault() ?? "").Trim().TrimStart('v'), "[^0-9.].*$", "");
        return Version.TryParse(v, out var x) ? x : null;
    }

    /// <summary>Install-AkariWingetTool: a winget of at least <see cref="Min"/>, checked once. Force (-Force,
    /// tools-fix-winget): App Installer installed again from winget-cli's latest release, whatever is there.</summary>
    public void EnsureTool(bool force = false)
    {
        if (force)
        {
            log.Write("winget: installing App Installer again");
            InstallAppInstaller();
            var now = ToolVersion();
            if (now is null || now < Min) throw new InvalidOperationException("winget could not be installed");
            log.Write($"winget: version {now} installed");
            _ready = true;
            return;
        }
        if (_ready) return;
        var v = ToolVersion();
        if (v is null || v < Min)
        {
            log.Write($"winget: {(v is null ? "not found" : $"version {v} is too old")}, installing App Installer");
            try { packages.RegisterByFamily(AppInstallerFamily); } catch (Exception) { }
            v = ToolVersion();
        }
        if (v is null || v < Min)
        {
            InstallAppInstaller();
            v = ToolVersion();
            if (v is null || v < Min) throw new InvalidOperationException("winget could not be installed");
            log.Write($"winget: version {v} installed");
        }
        _ready = true;
    }

    /// <summary>Install-AkariAppInstaller: its dependencies (this PC's architecture) and the msixbundle, from GitHub.</summary>
    private void InstallAppInstaller()
    {
        var tmp = Path.Combine(tempFolder, "akari-winget");
        Directory.CreateDirectory(tmp);
        var deps = Path.Combine(tmp, "deps.zip");
        var bundle = Path.Combine(tmp, "AppInstaller.msixbundle");
        http.Download($"{Release}/DesktopAppInstaller_Dependencies.zip", deps);
        http.Download($"{Release}/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle", bundle);
        var unpacked = Path.Combine(tmp, "deps");
        if (Directory.Exists(unpacked)) Directory.Delete(unpacked, recursive: true);
        Directory.CreateDirectory(unpacked);
        ZipFile.ExtractToDirectory(deps, unpacked);
        var arch = RuntimeInformation.OSArchitecture switch { Architecture.Arm64 => "arm64", Architecture.X86 => "x86", _ => "x64" };
        foreach (var f in Directory.GetFiles(unpacked, "*.appx", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase))
        {
            if (!f.Contains($"\\{arch}\\", StringComparison.OrdinalIgnoreCase)) continue;
            try { packages.Add(f); } catch (Exception) { }
        }
        packages.Add(bundle);
    }

    /// <summary>Install-AkariMicrosoftStore: for msstore installs and the Store's own restore. Each step logged.</summary>
    public void EnsureStore()
    {
        if (apps.IsInstalled(StorePackage)) return;
        log.Write("Microsoft Store: registering it again");
        foreach (var p in packages.AllUsers().Where(p => p.Name.Contains("WindowsStore", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(p.InstallLocation)))
        {
            var manifest = Path.Combine(p.InstallLocation!, "AppxManifest.xml");
            if (!File.Exists(manifest)) continue;
            try { packages.Register(manifest); } catch (Exception) { }
        }
        if (apps.IsInstalled(StorePackage)) return;
        log.Write("Microsoft Store: not on the disk any more, downloading it with winget");
        try
        {
            EnsureTool();
            var r = winget.Run(InstallArgs(StoreProductId, "msstore"));
            if (!Ok.Contains(r.Code)) log.Write($"Microsoft Store: winget failed (0x{r.Code:X8}): {LastLine(r)}");
        }
        catch (Exception e) { log.Write($"Microsoft Store: winget failed: {e.Message}"); }
        if (apps.IsInstalled(StorePackage)) return;
        log.Write("Microsoft Store: asking Windows to reinstall it (wsreset -i), this can take a few minutes");
        (exe ?? throw new InvalidOperationException("the engine can't run programs")).Run(Path.Combine(windowsFolder, "System32", "wsreset.exe"), "-i", wait: false);
        for (var i = 0; i < 60 && !apps.IsInstalled(StorePackage); i++) sleep(TimeSpan.FromSeconds(5));
        if (!apps.IsInstalled(StorePackage)) throw new InvalidOperationException("the Microsoft Store is still downloading: try again in a few minutes");
    }

    /// <summary>Install-AkariWingetPackage: one package, silently; msstore = a Store product id (the Store first).</summary>
    public void Install(string id, string source = "winget")
    {
        EnsureTool();
        if (source == "msstore") EnsureStore();
        log.Write($"winget: installing {id}");
        var r = winget.Run(InstallArgs(id, source));
        if (!Ok.Contains(r.Code)) throw new InvalidOperationException($"winget could not install {id} (0x{r.Code:X8}): {LastLine(r)}");
    }

    /// <summary>Test-AkariWingetInstalled: in winget's list of installed apps (by winget or not).</summary>
    public bool Installed(string id, string source = "winget")
    {
        WingetResult r;
        try { r = winget.Run("list", "--id", id, "--exact", "--source", source, "--accept-source-agreements", "--disable-interactivity"); }
        catch (Exception) { return false; }
        return r.Code == 0 && r.Output.Any(l => l.Contains(id, StringComparison.OrdinalIgnoreCase));
    }

    private static string[] InstallArgs(string id, string source) => ["install", "--id", id, "--exact", "--source", source, .. Flags];

    /// <summary>winget's last line with words in it (progress bars and spinners left out).</summary>
    private static string LastLine(WingetResult r) => (r.Output.LastOrDefault(l => Regex.IsMatch(l, "[A-Za-z]{3}")) ?? "").Trim();
}

/// <summary>The real winget.exe (guarded): on PATH, else the newest App Installer folder under WindowsApps.</summary>
public sealed class WingetExe : IWinget
{
    public WingetExe() => SystemGuard.Check("winget");

    public static string? Find()
    {
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            try { var f = Path.Combine(dir.Trim(), "winget.exe"); if (File.Exists(f)) return f; } catch (ArgumentException) { }
        }
        var apps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "WindowsApps");
        try
        {
            return Directory.GetDirectories(apps, "Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe")
                .Where(d => File.Exists(Path.Combine(d, "winget.exe")))
                .OrderByDescending(d => Version.TryParse(Path.GetFileName(d).Split('_')[1], out var v) ? v : new Version(0, 0))
                .Select(d => Path.Combine(d, "winget.exe")).FirstOrDefault();
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return null; }
    }

    public WingetResult Run(params string[] arguments)
    {
        var exe = Find() ?? throw new InvalidOperationException("winget is not available");
        var psi = new ProcessStartInfo(exe)
        {
            UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8,
        };
        foreach (var a in arguments) psi.ArgumentList.Add(a);
        using var p = Process.Start(psi) ?? throw new InvalidOperationException("winget did not start");
        var err = p.StandardError.ReadToEndAsync();
        var output = p.StandardOutput.ReadToEnd();
        p.WaitForExit();
        var lines = (output + err.Result).Split(["\r\n", "\n", "\r"], StringSplitOptions.None).Where(l => l.Length > 0).ToList();
        return new WingetResult(p.ExitCode, lines);
    }
}
