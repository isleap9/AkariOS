using System.Text;
using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.OneClick.Prepare;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>The steps the Tools › Drivers Actions share (src/Tweaks/Tools/Drivers/Files/Drivers.ps1): 7-Zip, DDU, the
/// NVIDIA lookup, the package in Downloads, the vendor's services.</summary>
internal static class DriverSteps
{
    public const string SettingsFile = "src/Tweaks/OneClick/Prepare/Files/ddu-settings.xml";

    /// <summary>Intel's driver downloads, newest first (DriverIntel.ps1 and DriverIntelDebloat.ps1).</summary>
    public const string IntelPage = "https://www.intel.com/content/www/us/en/search.html#sortCriteria=%40lastmodifieddt%20descending&f-operatingsystem_en=Windows%2011%20Family*&f-downloadtype=Drivers&cf-tabfilter=Downloads";

    /// <summary>Get-DriverSevenZip: 7-Zip's 7z.exe, installed from winget when missing.</summary>
    public static string SevenZip(TweakContext c)
    {
        var sevenZip = Path.Combine(TweakServices.Folder(c.Services.ProgramFiles, "Program Files"), "7-Zip", "7z.exe");
        if (!File.Exists(sevenZip)) TweakServices.Need(c.Services.Winget, "winget").Install("7zip.7zip");
        if (!File.Exists(sevenZip)) throw new InvalidOperationException("7-Zip is not installed, and winget could not install it");
        return sevenZip;
    }

    /// <summary>Expand-DriverArchive: the archive unpacked into the folder, emptied first.</summary>
    public static void Expand(TweakContext c, string archive, string dir)
    {
        if (Directory.Exists(dir))
        {
            // Remove-Item -Force: read-only files go too
            foreach (var f in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
            Directory.Delete(dir, recursive: true);
        }
        if (TweakServices.Need(c.Services.Exe, "program runner").Run(SevenZip(c), ExeArgs.Join("x", archive, $"-o{dir}", "-y")).ExitCode != 0)
            throw new InvalidOperationException($"{Path.GetFileName(archive)} could not be unpacked");
    }

    private static string Temp(TweakContext c) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "Temp");

    /// <summary>Initialize-DriverDdu: DDU in Windows\Temp\ddu with One-click's settings, read only. A Prepare step: it
    /// needs the network.</summary>
    public static void InitializeDdu(TweakContext c)
    {
        var dir = Path.Combine(Temp(c), "ddu");
        var exe = Path.Combine(Temp(c), "ddu.exe");
        TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save("ddu.exe", exe);
        Expand(c, exe, dir);
        DduSettings.Write(c, Path.Combine(dir, "Settings", "Settings.xml"), SettingsFile);
    }

    public const string NvidiaLookup = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=120&pfid=929&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1";

    /// <summary>Get-DriverNvidiaUrl: the latest WHQL GeForce driver's download link, from NVIDIA's own lookup (only
    /// IDS[0].downloadInfo.Version, read with the block's regex).</summary>
    public static string NvidiaUrl(TweakContext c)
    {
        var text = TweakServices.Need(c.Services.Http, "downloader").Text(NvidiaLookup);
        var m = Regex.Match(text, "\"downloadInfo\"\\s*:\\s*\\{[^{}]*?\"Version\"\\s*:\\s*\"([\\d.]+)\"", RegexOptions.IgnoreCase);
        if (!m.Success) throw new InvalidOperationException("NVIDIA's driver lookup gave no version");
        var v = m.Groups[1].Value;
        c.Log.Write($"Latest NVIDIA driver: {v}");
        return $"https://international.download.nvidia.com/Windows/{v}/{v}-desktop-win10-win11-64bit-international-dch-whql.exe";
    }

    /// <summary>Windows\Temp\&lt;name&gt;.</summary>
    public static string Temp(TweakContext c, string name) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "Temp", name);

    /// <summary>Find-DriverDownload: the newest file like the pattern (and not like notLike) in the real user's
    /// Downloads folder; null when there is none.</summary>
    public static string? FindDownload(TweakContext c, string like, string notLike = "")
    {
        var folder = FileData.UserFolder(c, "Downloads");
        if (!Directory.Exists(folder)) return null;
        return new DirectoryInfo(folder).EnumerateFiles(like)
            .Where(f => notLike.Length == 0 || !PsSemantics.Like(f.Name, notLike))
            .OrderByDescending(f => f.LastWriteTimeUtc).FirstOrDefault()?.FullName;
    }

    /// <summary>Get-DriverPackage: a full driver package from Downloads, or the vendor's page opened and a failure that
    /// says what to do.</summary>
    public static string Package(TweakContext c, string like, string notLike, string page, string vendor)
    {
        if (FindDownload(c, like, notLike) is { } f)
        {
            c.Log.Write($"Driver package: {Path.GetFileName(f)}");
            return f;
        }
        ShellStart.Run(c, page);
        throw new InvalidOperationException($"no {vendor} driver package ({like}) in your Downloads folder: download the full driver from the page that just opened, then press again");
    }

    /// <summary>Remove-DriverServices: each service stopped, then deleted.</summary>
    public static void RemoveServices(TweakContext c, params string[] names)
    {
        var services = TweakServices.Need(c.Services.Services, "service manager");
        foreach (var n in names)
        {
            services.Stop(n);
            services.Delete(n);
        }
    }

    /// <summary>Invoke-AkariExe: an installer run and waited for; a non-zero exit code only logged.</summary>
    public static void Install(TweakContext c, string exe, string what, params string[] arguments)
    {
        var code = TweakServices.Need(c.Services.Exe, "program runner").Run(exe, ExeArgs.Join(arguments)).ExitCode;
        if (code != 0) c.Log.Write($"{what} exit code: {code}");
    }

    /// <summary>Remove-Item -Recurse -Force -ErrorAction SilentlyContinue, for each path.</summary>
    public static void Delete(params string[] paths)
    {
        foreach (var p in paths) Apps.Remove.Files.Delete(p);
    }

    /// <summary>Get-Content -Raw, -replace, Set-Content -NoNewline: a text file edited in place, kept in its own encoding
    /// (its BOM; none = UTF-8; 5.1 writes ANSI, the same bytes for these ASCII files).</summary>
    public static void EditText(string path, Func<string, string> edit)
    {
        if (!File.Exists(path)) return;
        var bytes = File.ReadAllBytes(path);
        Encoding enc = bytes switch
        {
            [0xEF, 0xBB, 0xBF, ..] => new UTF8Encoding(true),
            [0xFF, 0xFE, ..] => new UnicodeEncoding(false, true),
            [0xFE, 0xFF, ..] => new UnicodeEncoding(true, true),
            _ => new UTF8Encoding(false),
        };
        var text = enc.GetString(bytes, enc.Preamble.Length, bytes.Length - enc.Preamble.Length);
        File.WriteAllBytes(path, [.. enc.Preamble, .. enc.GetBytes(edit(text))]);
    }

    /// <summary>Get-DriverDdu: DDU's program, ready from Prepare.</summary>
    public static string Ddu(TweakContext c)
    {
        var exe = Path.Combine(Temp(c), "ddu", "Display Driver Uninstaller.exe");
        if (!File.Exists(exe)) throw new InvalidOperationException("DDU is not ready (its download before the restart failed)");
        return exe;
    }
}
