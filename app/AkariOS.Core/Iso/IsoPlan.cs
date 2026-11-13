using System.Globalization;
using System.Text.RegularExpressions;
using AkariOS.Core.Unattend;
using static AkariOS.Core.Data.PsSemantics;

namespace AkariOS.Core.Iso;

/// <summary>
/// What a build is asked to do (Invoke-AkariIsoBuild's $Choices): the output folder, the source ISO (for the name),
/// the install image and edition (from opening the ISO), the option ids, the provisioned packages, features,
/// capabilities and OS packages to remove, the running AkariOS exe to copy in (AkariExe, the port's AkariDir; none =
/// left out), the answer file (none = left out).
/// </summary>
public sealed record IsoChoices
{
    public string OutDir { get; init; } = "";
    public string Iso { get; init; } = "";
    public string Image { get; init; } = "";
    public int Index { get; init; }
    public string Edition { get; init; } = "";
    public string[]? Options { get; init; }
    public string[]? Apps { get; init; }
    public string[]? Features { get; init; }
    public string[]? Capabilities { get; init; }
    public string[]? Packages { get; init; }
    public string? AkariExe { get; init; }
    public byte[]? Unattend { get; init; }
}

/// <summary>A build step: its id and the text the status bar shows.</summary>
public sealed record IsoStep(string Id, string Text);

/// <summary>An image in a .wim / .esd / .swm.</summary>
public sealed record WimImage(int Index, string Name, string Version, string? Architecture = null);

/// <summary>An edition the page offers: Supported = Windows 11 (build 22000+).</summary>
public sealed record IsoEdition(int Index, string Name, string Version, bool Supported);

/// <summary>A provisioned app of the image: its name and full package name.</summary>
public sealed record ImageApp(string Name, string Package);

/// <summary>The work folder &lt;out&gt;\AkariIso and its parts.</summary>
public sealed record IsoWork(string Root, string Media, string Mount, string Wim)
{
    public static IsoWork Of(string outDir)
    {
        var r = Path.Combine(outDir, "AkariIso");
        return new(r, Path.Combine(r, "Media"), Path.Combine(r, "Mount"), Path.Combine(r, "install.wim"));
    }
}

/// <summary>The build's pure parts (src/Core/Iso.ps1) and the page's (src/UI/IsoBuilder.ps1).</summary>
public static partial class IsoPlan
{
    public const long MinFree = 25L << 30;

    /// <summary>The build's ordered steps (New-AkariIsoPlan); <paramref name="picked"/> = the picked options.</summary>
    public static IReadOnlyList<IsoStep> Steps(IsoChoices c, IReadOnlyList<IsoOption> picked)
    {
        var s = new List<IsoStep>();
        void Add(string id, string text) => s.Add(new IsoStep(id, text));
        Add("Adk", "Getting the ISO tool ready (Windows ADK)");
        Add("Mount", $"Mounting {c.Edition}");
        if (List(c.Apps).Count > 0 || picked.Any(o => o.Apps.Count > 0)) Add("Apps", "Removing apps");
        if (List(c.Features).Count > 0 || picked.Any(o => o.Features.Count > 0)) Add("Features", "Removing Windows features");
        if (List(c.Capabilities).Count > 0) Add("Capabilities", "Removing optional features (capabilities)");
        if (List(c.Packages).Count > 0) Add("Packages", "Removing OS packages");
        Add("Registry", "Writing settings into the image's registry");
        Add("Files", "Removing files from the image");
        if (!string.IsNullOrEmpty(c.AkariExe)) Add("AkariOS", "Adding AkariOS to the image");
        Add("NetFx3", "Adding .NET Framework 3.5");
        Add("Cleanup", "Cleaning up the component store");
        Add("Commit", "Saving the image");
        Add("Compress", "Compressing install.wim");
        Add("Boot", "Skipping the Windows 11 requirements in setup (boot.wim)");
        if (c.Unattend is { Length: > 0 }) Add("Answer", "Adding the answer file (autounattend.xml)");
        Add("Iso", "Building the ISO");
        Add("Tidy", "Removing the work folder");
        return s;
    }

    /// <summary>A choice list without its empty entries (Get-AkariIsoList).</summary>
    public static IReadOnlyList<string> List(IEnumerable<string>? v) => [.. (v ?? []).Where(x => !string.IsNullOrEmpty(x))];

    /// <summary>The ISO's file name: &lt;source&gt;-Akari.iso.</summary>
    public static string OutName(string iso) => $"{(iso.Length > 0 ? Path.GetFileNameWithoutExtension(iso) : "Windows11")}-Akari.iso";

    /// <summary>oscdimg's arguments: BIOS + UEFI boot when the media has both boot files, UEFI only otherwise.</summary>
    public static IReadOnlyList<string> OscdimgArgs(string media, string output, Func<string, bool> exists)
    {
        var etfs = Path.Combine(media, @"boot\etfsboot.com");
        var efi = Path.Combine(media, @"efi\microsoft\boot\efisys.bin");
        if (!exists(efi)) throw new IsoException("The ISO has no efi\\microsoft\\boot\\efisys.bin: it can't boot.");
        var boot = exists(etfs) ? $"-bootdata:2#p0,e,b{etfs}#pEF,e,b{efi}" : $"-bootdata:1#pEF,e,b{efi}";
        return ["-m", "-o", "-u2", "-udfver102", boot, media, output];
    }

    /// <summary>A message when the output drive can't hold a build (not NTFS, under 25 GB free), else null.</summary>
    public static string? Space(long free, string format)
    {
        if (format != "NTFS") return $"The output folder must be on an NTFS drive (this one is {format}).";
        if (free < MinFree)
            return string.Format(CultureInfo.CurrentCulture, "The output drive needs {0} GB free (it has {1:N1} GB).", (double)MinFree / (1L << 30), (double)free / (1L << 30));
        return null;
    }

    /// <summary>The editions in an install image (Get-AkariIsoEditions).</summary>
    public static IReadOnlyList<IsoEdition> Editions(IEnumerable<WimImage> images) =>
        [.. images.Select(i => new IsoEdition(i.Index, i.Name, i.Version, Version.TryParse(i.Version, out var v) && v.Build >= 22000))];

    // ---- the page's helpers (UI\IsoBuilder.ps1)

    /// <summary>The answer file fields for "A local account" (Get-AkariIsoAnswerFields): the Unattend Generator's start
    /// fields with one administrator, or a local account made during setup when the setup questions stay; the
    /// partitioning fields left out (setup asks for the disk).</summary>
    public static Dictionary<string, string[]> AnswerFields(IReadOnlyDictionary<string, string[]> start, string user, string password, bool skipOobe)
    {
        var f = UnattendFields.Copy(start);
        foreach (var k in f.Keys.Where(k => Partitioning().IsMatch(k)).ToList()) f.Remove(k);
        f["PEMode"] = ["Default"];
        if (!skipOobe) { f["UserAccountMode"] = ["InteractiveLocal"]; return f; }
        var name = user.Trim().Length == 0 ? "Admin" : user.Trim();
        f["UserAccountMode"] = ["Unattended"];
        f["AccountName0"] = [name];
        f["AccountDisplayName0"] = [name];
        f["AccountPassword0"] = [password];
        f["AccountGroup0"] = ["Administrators"];
        f["AutoLogonMode"] = ["Own"];
        return f;
    }

    [GeneratedRegex("^(Partition|TargetDisk|SystemSize|Recovery|InstallFrom|PagingFile|InitPagingFile|MaxPagingFile)", RegexOptions.IgnoreCase)]
    private static partial Regex Partitioning();

    /// <summary>The image's apps the Remove tab recommends (Win11Debloat's Safe rows not on FR33THY's keep-list).</summary>
    public static IReadOnlyList<string> Recommended(IEnumerable<ImageApp> apps, IEnumerable<(string Id, string? Risk, bool Keep)> tweaks)
    {
        var safe = tweaks.Where(t => Like(t.Id, "appx/*") && string.Equals(t.Risk, "Safe", StringComparison.OrdinalIgnoreCase) && !t.Keep)
            .Select(t => t.Id[5..]).ToHashSet(StringComparer.OrdinalIgnoreCase);
        return [.. apps.Where(a => safe.Contains(a.Name)).Select(a => a.Package)];
    }
}
