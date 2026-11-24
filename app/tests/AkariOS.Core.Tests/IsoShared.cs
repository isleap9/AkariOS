using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Text.Json;
using System.Text.RegularExpressions;
using AkariOS.Core.Apps;
using AkariOS.Core.Iso;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;
using AkariOS.Core.Update;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

// The ISO Builder's test cases and recording fakes, shared by the oracle tests here and the App tests' ISO Builder
// page (linked there): an ISO's folders and test key (IsoBuildOracleTests.Side), a download's (IsoDownloadOracleTests
// .Side), the cases, IsoFakes behind IsoBuild and DownloadFakes behind IsoDownload.

public sealed partial class IsoBuildOracleTests
{
    // ---- the case

    internal static readonly string[] IsoFiles =
    [
        "setup.exe", @"sources\install.wim", @"sources\boot.wim", @"sources\sxs\microsoft-windows-netfx3.cab",
        @"boot\etfsboot.com", @"efi\microsoft\boot\efisys.bin",
    ];

    internal static readonly string[] ImageFiles =
    [
        @"Windows\System32\config\SOFTWARE", @"Windows\System32\config\SYSTEM", @"Windows\System32\config\DEFAULT", @"Users\Default\NTUSER.DAT",
        @"Windows\InboxApps\a.appx", @"Program Files\Internet Explorer\iexplore.exe", @"Windows\System32\UCPDMgr.exe",
        @"Windows\SystemApps\MicrosoftWindows.Client.AIX_cw5n1h2txyewy\a.dll", @"Program Files\Windows Defender\MsMpEng.exe",
        @"Program Files\WindowsApps\Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe\a.dll", @"Windows\SystemApps\Microsoft.BingNews_cw5n1h2txyewy\b.dll",
        @"Program Files\WindowsApps\Microsoft.SecHealthUI_1000.0.0.0_x64__8wekyb3d8bbwe\c.dll",
    ];

    private const string Store = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore";

    internal static Dictionary<string, object> Case(Action<Dictionary<string, object>>? change = null)
    {
        var media = @"<root>\out\AkariIso\Media\sources";
        var c = new Dictionary<string, object>
        {
            ["Actions"] = new[] { "Open", "Build" },
            ["Drive"] = new { Free = 30L << 30, Format = "NTFS" },
            ["Wims"] = new Dictionary<string, object[]>
            {
                [$@"{media}\install.wim"] = [new { Index = 1, Name = "Windows 11 Home", Version = "10.0.26100.1742" }, new { Index = 6, Name = "Windows 11 Pro", Version = "10.0.26100.1742" }],
                [$@"{media}\boot.wim"] = [new { Index = 1, Name = "Microsoft Windows PE", Version = "10.0.26100.1" }, new { Index = 2, Name = "Microsoft Windows Setup", Version = "10.0.26100.1" }],
            },
            ["ImageFiles"] = ImageFiles,
            ["BootFiles"] = new[] { @"Windows\System32\config\SOFTWARE", @"Windows\System32\config\SYSTEM" },
            ["ImageApps"] = new object[]
            {
                new { Name = "Microsoft.BingNews", Package = "Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.SecHealthUI", Package = "Microsoft.SecHealthUI_1000.0.0.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.Copilot", Package = "Microsoft.Copilot_1.0.0.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.VCLibs.140.00", Package = "Microsoft.VCLibs.140.00_14.0.0.0_x64__8wekyb3d8bbwe" },
                new { Name = "Microsoft.WindowsCalculator", Package = "Microsoft.WindowsCalculator_11.0.0.0_x64__8wekyb3d8bbwe" },
            },
            ["ImageFeatures"] = new[] { "Windows-Defender-Default-Definitions", "Recall", "Printing-PrintToPDFServices-Features" },
            ["DismCodes"] = new Dictionary<string, int>(),
            ["Fail"] = "",
            ["Denied"] = Array.Empty<string>(),
            ["Choices"] = new Dictionary<string, object> { ["Index"] = 6, ["Edition"] = "Windows 11 Pro" },
        };
        change?.Invoke(c);
        return c;
    }

    internal static Dictionary<string, object> Choices(Dictionary<string, object> c) => (Dictionary<string, object>)c["Choices"];

    /// <summary>JSON with '&lt;root&gt;' kept as text (the default encoder writes <), so each side can put its own
    /// folder in.</summary>
    internal static string Json(object o) =>
        JsonSerializer.Serialize(o, new JsonSerializerOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping });

    // ---- one side's folders and test key

    internal sealed class Side : IDisposable
    {
        public string Root { get; } = Path.Combine(Path.GetTempPath(), $"akari-isob-{Guid.NewGuid():N}");
        public TestKey Key { get; } = new();

        public Side(Dictionary<string, object> c)
        {
            bool Without(string key) => c.TryGetValue(key, out var v) && v is true;
            foreach (var f in IsoFiles)
            {
                if ((Without("NoSxs") && f.Contains("sxs")) || (Without("NoInstall") && f.Contains("install")) || (Without("NoEtfs") && f.Contains("etfs"))) continue;
                var p = Path.Combine(Root, "drive", f);
                Directory.CreateDirectory(Path.GetDirectoryName(p)!);
                File.WriteAllText(p, "x");
                File.SetAttributes(p, FileAttributes.ReadOnly);
            }
            Directory.CreateDirectory(Path.Combine(Root, "out"));
            var reg = new RegistryEngine(Key.Paths);
            reg.SetValue($@"{IsoData.HiveRoot}SOFTWARE\Microsoft\Windows NT\CurrentVersion", Without("NoDisplayVersion") ? "ProductName" : "DisplayVersion", "24H2", "String");
            foreach (var k in new[] { "InboxApplications", "Applications", "Staged" })
                reg.SetValue($@"{IsoData.HiveRoot}{Store}\{k}\Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe", "Path", "x", "String");
            reg.SetValue($@"{IsoData.HiveRoot}{Store}\InboxApplications\MicrosoftWindows.Client.CoreAI_1000.0.0.0_x64__cw5n1h2txyewy", "Path", "x", "String");
            reg.SetValue($@"{IsoData.HiveRoot}{Store}\InboxApplications\Microsoft.WindowsCalculator_11.0.0.0_x64__8wekyb3d8bbwe", "Path", "x", "String");
            reg.SetValue($@"{IsoData.HiveRoot}NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions\1", "x", 1u, "DWord");
        }

        public void Dispose()
        {
            Key.Dispose();
            if (!Directory.Exists(Root)) return;
            foreach (var f in Directory.EnumerateFiles(Root, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
            Directory.Delete(Root, recursive: true);
        }

        /// <summary>The hives' state: every key and value under the test key's HKLM\AkariIso_*.</summary>
        public List<string> Registry()
        {
            var list = new List<string>();
            using var hkcu = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64);
            using var hklm = hkcu.OpenSubKey($@"{Key.Root}\HKLM");
            if (hklm is null) return list;
            void Walk(RegistryKey k, string at)
            {
                list.Add(at);
                foreach (var n in k.GetValueNames().Order(StringComparer.OrdinalIgnoreCase))
                {
                    var v = k.GetValue(n, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                    var text = v switch { byte[] b => Convert.ToHexString(b), string[] s => string.Join(",", s), _ => $"{v}" };
                    list.Add($"{at}|{n}|{k.GetValueKind(n)}|{text}");
                }
                foreach (var s in k.GetSubKeyNames().Order(StringComparer.OrdinalIgnoreCase))
                {
                    using var sub = k.OpenSubKey(s)!;
                    Walk(sub, $@"{at}\{s}");
                }
            }
            foreach (var s in hklm.GetSubKeyNames().Order(StringComparer.OrdinalIgnoreCase))
            {
                using var sub = hklm.OpenSubKey(s)!;
                Walk(sub, s);
            }
            return list;
        }
    }
}

/// <summary>The recording fakes behind IsoBuild in IsoBuildOracleTests (and IsoBuildTests, the App's ISO Builder page):
/// they answer the case as Oracle/Invoke-IsoBuild.ps1's recorders do and write the same neutral calls.</summary>
internal sealed class IsoFakes : IImage, IOfflineHives, IDiskImage, IExe, ITrustedInstaller, IRegistryPaths, IShortcuts, IHttp
{
    private readonly IsoBuildOracleTests.Side _side;
    private readonly JsonElement _c;
    private readonly RedirectedRegistryPaths _inner;
    private readonly string[] _denied;
    private bool _inTrusted;

    public List<string> Calls { get; } = [];
    public List<string> Shortcuts { get; } = [];
    public List<string> Downloads { get; } = [];
    public List<string> ProgressLines { get; } = [];
    public MemoryLog Log { get; } = new();
    public IProgress<RunProgress> Progress { get; }
    public IsoParts Parts { get; set; }

    /// <summary>Called when oscdimg runs (IsoBuildTests: the media as it is then).</summary>
    public Action? OnOscdimg { get; set; }

    /// <summary>Called with the mount folder before a commit empties it.</summary>
    public Action<string>? OnCommit { get; set; }

    /// <summary>Called with any other program run (the ADK's setup).</summary>
    public Action<string, string>? OnExe { get; set; }

    /// <summary>How many unloads fail before they work.</summary>
    public int UnloadFailures { get; set; }

    public List<(string Path, string Args, bool Wait, bool Capture)> Runs { get; } = [];

    public IsoFakes(IsoBuildOracleTests.Side side, Dictionary<string, object> c)
    {
        _side = side;
        _c = JsonDocument.Parse(IsoBuildOracleTests.Json(c).Replace("<root>", side.Root.Replace(@"\", @"\\"))).RootElement;
        _inner = side.Key.Paths;
        _denied = [.. _c.GetProperty("Denied").EnumerateArray().Select(e => e.GetString()!)];
        Progress = new Recorder(p => ProgressLines.Add($"{p.Done}/{p.Total} {p.Step}"));
        var pf86 = Path.Combine(side.Root, "pf86");
        var oscdimg = Path.Combine(pf86, @"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(oscdimg)!);
        File.WriteAllText(oscdimg, "");
        var drive = _c.GetProperty("Drive");
        Parts = new IsoParts
        {
            Files = new FolderSourceFiles(Repo.Root), Image = this, Hives = this, Disk = this, Registry = new RegistryEngine(this, this), Trusted = this,
            Exe = this, Http = this, Shortcuts = this, Log = Log, Marker = Path.Combine(side.Root, "iso-mount.json"), Windows = @"C:\Windows",
            ProgramFilesX86 = pf86, Temp = Path.Combine(side.Root, "temp"), Drive = _ => (drive.GetProperty("Free").GetInt64(), drive.GetProperty("Format").GetString()!),
            Sleep = _ => { },
        };
    }

    private sealed class Recorder(Action<RunProgress> on) : IProgress<RunProgress>
    {
        public void Report(RunProgress value) => on(value);
    }

    /// <summary>The build's operations as they were reported, and the last build's report.</summary>
    public List<IsoOperation> Ops { get; } = [];
    public IProgress<IsoOperation> Operations => new OpRecorder(Ops.Add);
    public IsoReport? Report { get; set; }

    private sealed class OpRecorder(Action<IsoOperation> on) : IProgress<IsoOperation>
    {
        public void Report(IsoOperation value) => on(value);
    }

    public string Norm(string s) => s.Replace(_side.Root, "<root>");

    private void Rec(string s) => Calls.Add(Norm(s));

    private string Fail => _c.GetProperty("Fail").GetString()!;

    public string MakeExe()
    {
        var exe = Path.Combine(_side.Root, "akari", "AkariOS-Native.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(exe)!);
        File.WriteAllText(exe, "exe");
        return exe;
    }

    private static void ClearMount(string mount)
    {
        if (!Directory.Exists(mount)) return;
        foreach (var d in Directory.EnumerateDirectories(mount)) Directory.Delete(d, recursive: true);
        foreach (var f in Directory.EnumerateFiles(mount)) File.Delete(f);
    }

    private readonly HashSet<string> _disabled = new(StringComparer.OrdinalIgnoreCase);

    private int Code(string verb) => _c.GetProperty("DismCodes").TryGetProperty(verb, out var v) ? v.GetInt32() : 0;

    // ---- IImage

    public IReadOnlyList<WimImage> Images(string wim)
    {
        Rec($"WimImages {wim}");
        return _c.GetProperty("Wims").TryGetProperty(wim, out var list)
            ? [.. list.EnumerateArray().Select(i => new WimImage(i.GetProperty("Index").GetInt32(), i.GetProperty("Name").GetString()!, i.GetProperty("Version").GetString()!))]
            : [];
    }

    public void Export(string source, int index, string dest, string compression)
    {
        Rec($"Export {source} {index} {dest} {compression}");
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        File.WriteAllText(dest, "");
    }

    public void Mount(string wim, int index, string mount)
    {
        Rec($"Mount {wim} {index} {mount}");
        if (Fail == "Mount") throw new InvalidOperationException("The image could not be mounted.");
        var files = Path.GetFileName(wim) == "boot.wim" ? "BootFiles" : "ImageFiles";
        foreach (var f in _c.GetProperty(files).EnumerateArray())
        {
            var p = Path.Combine(mount, f.GetString()!);
            Directory.CreateDirectory(Path.GetDirectoryName(p)!);
            File.WriteAllText(p, "");
        }
    }

    public void Commit(string mount) { Rec($"Commit {mount}"); OnCommit?.Invoke(mount); ClearMount(mount); }

    public void Discard(string mount) { Rec($"Discard {mount}"); ClearMount(mount); }

    public IReadOnlyList<ImageApp> ProvisionedApps(string mount)
    {
        Rec($"Read Apps {mount}");
        return [.. _c.GetProperty("ImageApps").EnumerateArray().Select(a => new ImageApp(a.GetProperty("Name").GetString()!, a.GetProperty("Package").GetString()!))];
    }

    public IReadOnlyList<DismItem> Features(string mount)
    {
        Rec($"Read Features {mount}");
        // a feature removed reads back disabled, unless the case keeps it ("StuckFeatures": DISM said done, it isn't)
        var stuck = _c.TryGetProperty("StuckFeatures", out var s) ? s.EnumerateArray().Select(x => x.GetString()).ToHashSet() : [];
        return [.. _c.GetProperty("ImageFeatures").EnumerateArray().Select(n => n.GetString()!)
            .Select(n => new DismItem(n, _disabled.Contains(n) && !stuck.Contains(n) ? "DisabledWithPayloadRemoved" : "Enabled"))];
    }

    public IReadOnlyList<DismItem> Capabilities(string mount)
    {
        Rec($"Read Capabilities {mount}");
        return _c.TryGetProperty("ImageCapabilities", out var l)
            ? [.. l.EnumerateArray().Select(i => new DismItem(i.GetProperty("Name").GetString()!, i.GetProperty("State").GetString()!))]
            : [];
    }

    public IReadOnlyList<DismItem> Packages(string mount)
    {
        Rec($"Read Packages {mount}");
        return _c.TryGetProperty("ImagePackages", out var l) ? [.. l.EnumerateArray().Select(n => new DismItem(n.GetString()!, "Installed"))] : [];
    }

    public int Remove(string mount, string kind, string name)
    {
        Rec($"Remove {kind} {mount} {name}");
        if (kind == "Feature") _disabled.Add(name);
        return Code(kind switch { "Feature" => "Disable-Feature", "Capability" => "Remove-Capability", _ => "Remove-Package" });
    }

    public int Dism(IReadOnlyList<string> arguments)
    {
        Rec("Dism " + string.Join(" ", arguments));
        if (arguments[1] == "/Disable-Feature")
            foreach (var a in arguments.Where(a => a.StartsWith("/FeatureName:", StringComparison.Ordinal))) _disabled.Add(a["/FeatureName:".Length..]);
        return Code(arguments[1].TrimStart('/'));
    }

    // ---- IOfflineHives, IDiskImage

    public bool Load(string name, string file) { Rec($"HiveLoad {name} {file}"); return true; }

    public bool Unload(string name)
    {
        Rec($"HiveUnload {name}");
        if (UnloadFailures <= 0) return true;
        UnloadFailures--;
        return false;
    }

    string IDiskImage.Mount(string iso) { Rec($"DiskMount {iso}"); return Path.Combine(_side.Root, "drive") + @"\"; }

    public void Dismount(string iso) => Rec($"DiskDismount {iso}");

    // ---- IExe: takeown = Own, icacls quiet, oscdimg recorded with its arguments

    public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true)
    {
        var name = Path.GetFileName(path).ToLowerInvariant();
        var args = Args(arguments);
        Runs.Add((path, arguments, wait, capture));
        switch (name)
        {
            case "takeown.exe": Rec($"Own {args[1]}"); return new ExeResult(0, "");
            case "icacls.exe": return new ExeResult(0, "");
            case "oscdimg.exe":
                OnOscdimg?.Invoke();
                Rec("Oscdimg " + string.Join(" ", args));
                if (Fail == "Oscdimg") return new ExeResult(2, "");
                // the ISO (the build hashes it), as the PowerShell recorder writes it
                if (!File.Exists(args[^1])) File.WriteAllText(args[^1], "iso");
                return new ExeResult(0, "");
            default: Rec($"Exe {name} {arguments}"); OnExe?.Invoke(path, arguments); return new ExeResult(0, "");
        }
    }

    /// <summary>A command line split back into its arguments (quotes around one that has spaces).</summary>
    public static List<string> Args(string line) =>
        [.. Regex.Matches(line, "\"([^\"]*)\"|(\\S+)").Select(m => m.Groups[1].Success ? m.Groups[1].Value : m.Groups[2].Value)];

    // ---- ITrustedInstaller: what is written meanwhile is recorded by Resolve

    void ITrustedInstaller.Run(Action work)
    {
        if (Fail == "Trusted") throw new InvalidOperationException("TrustedInstaller failed.");
        _inTrusted = true;
        try { work(); }
        finally { _inTrusted = false; }
    }

    // ---- IRegistryPaths: the test key; a denied path throws unless written as TrustedInstaller

    public RegKeyPath Resolve(string path)
    {
        var at = path.IndexOf("AkariIso_", StringComparison.Ordinal);
        var hive = at < 0 ? null : path[(at + 9)..].TrimEnd('\\');
        if (_inTrusted && hive is not null) Rec($"Trusted {hive}");
        else if (hive is not null && _denied.Any(d => hive.Equals(d, StringComparison.OrdinalIgnoreCase) || hive.StartsWith(d + @"\", StringComparison.OrdinalIgnoreCase)))
            throw new UnauthorizedAccessException("Requested registry access is not allowed.");
        return _inner.Resolve(path);
    }

    // ---- IShortcuts, IHttp

    public void Create(string link, string target, string? workingDirectory = null) =>
        Shortcuts.Add($"{Norm(link)}|{target}|{workingDirectory}");

    public void Download(string url, string file)
    {
        Downloads.Add($"{url}|{Norm(file)}");
        File.WriteAllText(file, "setup");
    }
}

public sealed partial class IsoDownloadOracleTests
{
    internal const string BuildId = "5f3a6b1c-0d2e-4c8f-9a7b-1e2d3c4b5a69";

    internal static object Ok(object response) => new { Json = new { response } };

    internal static object Fail(string message) => new { Throw = message };

    internal static readonly object ListId = Ok(new
    {
        builds = new Dictionary<string, object>
        {
            ["0"] = new { uuid = BuildId, title = "Windows 11, version 25H2 (26200.6584) amd64", build = "26200.6584", arch = "amd64" },
            ["1"] = new { uuid = "older", title = "Windows 11, version 25H2 (26200.6000) amd64", build = "26200.6000", arch = "amd64" },
            ["2"] = new { uuid = "preview", title = "Windows 11 Insider Preview 26200.7000 amd64", build = "26200.7000", arch = "amd64" },
        },
    });

    internal static readonly object ListLangs = Ok(new { langFancyNames = new Dictionary<string, string> { ["fr-fr"] = "French", ["en-us"] = "English (United States)", ["de-de"] = "German" } });

    internal static readonly object ListEditions = Ok(new { editionFancyNames = new Dictionary<string, string> { ["PROFESSIONAL"] = "Windows Pro", ["CORE"] = "Windows Home", ["PROFESSIONALN"] = "Windows Pro N" } });

    internal const string Ini = "[convert-UUP]\r\nAutoStart    =1\r\nAddUpdates   =1\r\nResetBase    =0\r\nNetFx3       =0\r\nStartVirtual =0\r\n\r\n[create_virtual_editions]\r\nvAutoEditions=\r\nvDeleteSource=0\r\n\r\n[Store_Apps]\r\nAutoExit     =0\r\n";

    /// <summary>A Massgrave page listing one product's files (English, x64).</summary>
    internal static string Page(string product, params string[] files) =>
        $"# Links\n\n**{product}**\n\n| Language | Arch | Link |\n|---|---|---|\n" +
        string.Concat(files.Select(f => $"| English | x64 | [{f}](https://drive.massgrave.dev/{f}) |\n"));

    internal static Dictionary<string, object> Case(params object[] actions) => new()
    {
        ["Actions"] = actions,
        ["Answers"] = Array.Empty<object>(),
        ["Package"] = new { Files = new Dictionary<string, string> { ["ConvertConfig.ini"] = Ini, ["uup_download_windows.cmd"] = "@echo off" } },
        ["Script"] = new { Code = 0, Iso = "26200.6584.250915-1200.ge_release_CLIENTPRO_OEMRET_x64FRE_en-us.iso", Lines = new[] { "Downloading 1 of 3", "", "Done" } },
        ["Pages"] = new Dictionary<string, string?>(),
        ["Drive"] = new { Free = 40L << 30, Format = "NTFS" },
        ["Downloads"] = Array.Empty<object>(),
    };

    // ---- one side

    internal sealed class Side : IDisposable
    {
        /// <summary>The downloads' clock: each file is Age minutes older (Invoke-IsoDownload.ps1's FindNew uses it too).</summary>
        public static readonly DateTime Now = new(2026, 11, 13, 12, 0, 0, DateTimeKind.Utc);

        public string Root { get; } = Path.Combine(Path.GetTempPath(), $"akari-isod-{Guid.NewGuid():N}");

        public Side(Dictionary<string, object> c)
        {
            Directory.CreateDirectory(Path.Combine(Root, "out"));
            var downloads = Directory.CreateDirectory(Path.Combine(Root, "downloads")).FullName;
            var now = Now;
            foreach (var d in JsonDocument.Parse(IsoBuildOracleTests.Json(c["Downloads"])).RootElement.EnumerateArray())
            {
                var f = Path.Combine(downloads, d.GetProperty("Name").GetString()!);
                File.WriteAllText(f, "iso");
                File.SetLastWriteTimeUtc(f, now.AddMinutes(-d.GetProperty("Age").GetInt32()));
            }
        }

        public void Dispose() { if (Directory.Exists(Root)) Directory.Delete(Root, recursive: true); }

        public List<string> Files() => [.. Directory.EnumerateFileSystemEntries(Path.Combine(Root, "out"), "*", SearchOption.AllDirectories)
            .Select(f => f.Replace(Root, "<root>")).Order(StringComparer.OrdinalIgnoreCase)];
    }
}

/// <summary>The recording fakes behind IsoDownload in IsoDownloadOracleTests (and the App's ISO Builder page): they
/// answer the case as Oracle/Invoke-IsoDownload.ps1's recorders do and write the same calls.</summary>
internal sealed class DownloadFakes : IHttp, IExe
{
    private readonly string _root;
    private int _answer;

    public JsonElement Case { get; }
    public List<string> Calls { get; } = [];
    public MemoryLog Log { get; } = new();
    public IsoDownloadParts Parts { get; set; }

    public DownloadFakes(string root, Dictionary<string, object> c)
    {
        _root = root;
        Case = JsonDocument.Parse(IsoBuildOracleTests.Json(c).Replace("<root>", root.Replace(@"\", @"\\"))).RootElement;
        var drive = Case.GetProperty("Drive");
        Parts = new IsoDownloadParts
        {
            Http = this, Exe = this, Log = Log, Windows = @"C:\Windows",
            Drive = _ => (drive.GetProperty("Free").GetInt64(), drive.GetProperty("Format").GetString()!),
            Sleep = ms => Rec($"Sleep {ms / 1000}"),
            Downloads = () => Path.Combine(root, "downloads"),
        };
    }

    public string Norm(string s) => s.Replace(_root, "<root>");

    private void Rec(string s) => Calls.Add(Norm(s));

    private static string Query(IEnumerable<KeyValuePair<string, string>> q) =>
        string.Join("&", q.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => $"{p.Key}={p.Value}"));

    public string Text(string url, IReadOnlyDictionary<string, string>? headers = null)
    {
        const string api = "https://api.uupdump.net/";
        if (url.StartsWith(api, StringComparison.Ordinal))
        {
            var u = new Uri(url);
            var name = Path.GetFileNameWithoutExtension(u.AbsolutePath);
            var q = u.Query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries)
                .Select(p => p.Split('=', 2)).Select(p => KeyValuePair.Create(Uri.UnescapeDataString(p[0]), Uri.UnescapeDataString(p[1])));
            Rec($"Api {name} {Query(q)}");
            var answers = Case.GetProperty("Answers");
            if (_answer >= answers.GetArrayLength()) throw new InvalidOperationException("no answer left");
            var a = answers[_answer++];
            if (a.TryGetProperty("Throw", out var t)) throw new HttpRequestException(t.GetString());
            return a.GetProperty("Json").GetRawText();
        }
        Rec($"Page {url}");
        if (!Case.GetProperty("Pages").TryGetProperty(url, out var page) || page.ValueKind == JsonValueKind.Null) throw new HttpRequestException("404 Not Found");
        return page.GetString()!;
    }

    public void Download(string url, string file) => throw new NotSupportedException();

    public void Post(string url, IReadOnlyDictionary<string, string> form, string file)
    {
        Rec($"Package {url} {Query(form)}");
        var p = Case.GetProperty("Package");
        if (p.TryGetProperty("Throw", out var t)) throw new HttpRequestException(t.GetString());
        using var zip = ZipFile.Open(file, ZipArchiveMode.Create);
        foreach (var f in p.GetProperty("Files").EnumerateObject())
        {
            using var w = new StreamWriter(zip.CreateEntry(f.Name).Open());
            w.Write(f.Value.GetString());
        }
    }

    public ExeResult Run(string path, string arguments, bool wait = true, bool capture = true) => throw new NotSupportedException();

    public int Lines(string path, string arguments, string folder, Action<string> line)
    {
        Assert.Equal(@"C:\Windows\System32\cmd.exe", path);
        Assert.Equal("/c uup_download_windows.cmd", arguments);
        Rec($"Script {folder}");
        Rec("Ini " + Convert.ToBase64String(File.ReadAllBytes(Path.Combine(folder, "ConvertConfig.ini"))));
        var s = Case.GetProperty("Script");
        foreach (var l in s.GetProperty("Lines").EnumerateArray()) line(l.GetString()!);
        if (s.GetProperty("Iso").GetString() is { Length: > 0 } iso) File.WriteAllText(Path.Combine(folder, iso), "iso");
        return s.GetProperty("Code").GetInt32();
    }
}
