using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;

namespace AkariOS.Core.Support;

/// <summary>
/// The support file (src/Core/Support.ps1, plan 2026-11-26-new-features.md X1): a zip with what a bug report needs,
/// the user's and the PC's names taken out of every text. Nothing is sent anywhere. <see cref="Scrub"/> is compared
/// with ConvertTo-AkariSupportText by SupportOracleTests.
/// </summary>
public static class SupportFile
{
    /// <summary>Profile folders whose name is Windows', not a person's.</summary>
    public static readonly string[] KeepProfiles = ["Public", "Default", "Default User", "All Users"];

    private const RegexOptions Options = RegexOptions.IgnoreCase | RegexOptions.CultureInvariant;

    private static readonly Regex ProfilePath = new(
        @"(\b[a-z]:(?:\\\\|\\|/)Users(?:\\\\|\\|/))(?!(?:" + string.Join("|", KeepProfiles.Select(Regex.Escape)) + @")(?:\\|/|""|$))[^\\/""\r\n\s]+",
        Options);

    /// <summary>ConvertTo-AkariSupportText (pure): every profile path's user folder as &lt;user&gt;, then each user
    /// name as &lt;user&gt; and the computer's as &lt;pc&gt;, whole words, ignoring case, the longest first; names
    /// shorter than 2 characters are left alone.</summary>
    public static string Scrub(string? text, IEnumerable<string?> users, string? computer)
    {
        if (string.IsNullOrEmpty(text)) return "";
        text = ProfilePath.Replace(text, "$1<user>");
        var pairs = users.Select(u => (u ?? "").Trim()).Where(u => u.Length >= 2).Select(u => (Name: u, Token: "<user>")).ToList();
        if ((computer ?? "").Trim() is { Length: >= 2 } c) pairs.Add((c, "<pc>"));
        foreach (var (name, token) in pairs.OrderByDescending(p => p.Name.Length))
            text = Regex.Replace(text, @"(?<!\w)" + Regex.Escape(name) + @"(?!\w)", token.Replace("$", "$$"), Options);
        return text;
    }

    /// <summary>The names to take out: the account the app runs as and the real user's profile folder.</summary>
    public static IReadOnlyList<string> Users(Engine engine)
    {
        var list = new List<string> { Environment.UserName };
        try
        {
            if (UserFolders.Get(engine.Registry, "Local AppData", engine.Services.UserSid) is { Length: > 0 } local
                && Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(local))) is { Length: > 0 } name)
                list.Add(name);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException) { }
        return list.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }

    /// <summary>The native app's files that go in (the ones that exist are added).</summary>
    public static IReadOnlyList<string> Files() =>
    [
        AkariPaths.LogFile, AkariPaths.StateFile,
        Path.Combine(AkariPaths.UserFolder, "activity.json"),
        Path.Combine(AkariPaths.UserFolder, "settings.json"),
        Path.Combine(AkariPaths.UserFolder, "lastused.json"),
        Path.Combine(AkariPaths.MachineFolder, "run.json"),
    ];

    private static readonly Regex VirtualName = new(@"Virtual Machine|VMware|VirtualBox|innotek|QEMU|\bKVM\b|\bXen\b|Parallels|Bochs", RegexOptions.IgnoreCase);

    /// <summary>Test-AkariVirtualName (pure): a virtual machine's firmware names.</summary>
    public static bool IsVirtual(string? manufacturer, string? product) => VirtualName.IsMatch($"{manufacturer}|{product}");

    /// <summary>system.txt's lines (Get-AkariSupportInfo).</summary>
    public static IReadOnlyList<string> Info(Engine engine, DateTime now, string app = "native app")
    {
        string Reg(string path, string name) => PsSemantics.Text(engine.Registry.GetValue(path, name)) ?? "";
        static string YesNo(bool b) => b ? "Yes" : "No";
        const string nt = @"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion";
        const string bios = @"HKLM:\HARDWARE\DESCRIPTION\System\BIOS";
        var lines = new List<string>
        {
            $"AkariOS {AkariInfo.Version} ({app})",
            $"Windows: {Reg(nt, "ProductName")} {Reg(nt, "DisplayVersion")}, build {Reg(nt, "CurrentBuild")}.{Reg(nt, "UBR")}",
            $"Edition: {engine.System.Edition}",
            $"Chassis: {engine.System.Chassis}",
            $"Virtual machine: {YesNo(IsVirtual(Reg(bios, "SystemManufacturer"), Reg(bios, "SystemProductName")))}",
            $"Safe Mode: {YesNo(engine.InSafeMode())}",
            $"Administrator: {YesNo(engine.IsAdmin())}",
        };
        if (engine.System.Gpus.Count == 0) lines.Add("GPU: none found");
        foreach (var g in engine.System.Gpus)
            lines.Add($"GPU: {g.Name} ({g.Vendor}), driver {Reg(g.Path, "DriverVersion")} {Reg(g.Path, "DriverDate")}".TrimEnd());
        lines.Add($"Created: {now:yyyy-MM-dd HH:mm}");
        return lines;
    }

    /// <summary>New-AkariSupportFile: writes the zip (replacing one already there) and returns the files added
    /// (system.txt not counted). A file that can't be read is skipped and logged.</summary>
    public static int Make(string path, IEnumerable<string?> files, IReadOnlyList<string> info, IReadOnlyList<string> users, string? computer, IAkariLog? log = null)
    {
        if (File.Exists(path)) File.Delete(path);
        var utf8 = new UTF8Encoding(false);
        var count = 0;
        using var zip = new ZipArchive(File.Open(path, FileMode.CreateNew), ZipArchiveMode.Create);
        void Add(string name, string text)
        {
            using var w = new StreamWriter(zip.CreateEntry(name).Open(), utf8);
            w.Write(Scrub(text, users, computer));
        }
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var f in files)
        {
            if (string.IsNullOrEmpty(f) || !File.Exists(f) || !names.Add(Path.GetFileName(f))) continue;
            try
            {
                Add(Path.GetFileName(f), ReadShared(f));
                count++;
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { log?.WriteFile($"Support file: {f} not added ({e.Message})"); }
        }
        Add("system.txt", string.Join("\r\n", info) + "\r\n");
        return count;
    }

    /// <summary>A file's text while another program may be writing it.</summary>
    private static string ReadShared(string path)
    {
        using var s = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        using var r = new StreamReader(s, Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
        return r.ReadToEnd();
    }
}
