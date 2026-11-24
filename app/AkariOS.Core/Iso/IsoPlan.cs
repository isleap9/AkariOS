using System.Globalization;
using System.Text.RegularExpressions;
using AkariOS.Core.Unattend;
using static AkariOS.Core.Data.PsSemantics;

namespace AkariOS.Core.Iso;

/// <summary>
/// What a build is asked to do (Invoke-AkariIsoBuild's $Choices): the output folder, the source ISO (for the name),
/// the install image and edition (from opening the ISO), the provisioned packages, features,
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
    public string[]? Apps { get; init; }
    public string[]? Features { get; init; }
    public string[]? Capabilities { get; init; }
    public string[]? Packages { get; init; }
    public string? AkariExe { get; init; }
    public byte[]? Unattend { get; init; }

    /// <summary>The wizard's build settings (batch I3, native only so far); the defaults build as the port does.</summary>
    public IsoBuildSettings Settings { get; init; } = new();

    /// <summary>The removal groups (<see cref="IsoWizard.Groups"/> ids; null or empty = none): nothing else is always
    /// on.</summary>
    public string[]? Groups { get; init; }

    /// <summary>App names or wildcards matched on the image's apps when it is built (the groups' apps, 'appx:' tokens
    /// already expanded: <see cref="IsoWizard.AppPatterns"/>).</summary>
    public string[]? AppPatterns { get; init; }

    /// <summary>The AkariOS mode's Tweaks written into the image's hives (<see cref="IsoWizard.Bake"/>).</summary>
    public IReadOnlyList<IsoBakeItem>? Bake { get; init; }

    /// <summary>The rest of the AkariOS preset at each new account's first sign-in (a RunOnce entry in the Default
    /// user's hive); needs <see cref="AkariExe"/>.</summary>
    public bool FirstSignIn { get; init; }

    /// <summary>The edition's build (26100…), for the baked Tweaks' per-OS rows; 0 = unknown (Windows 11).</summary>
    public int ImageBuild { get; init; }
}

/// <summary>How install.wim leaves the build: Recovery = install.esd (/Compress:recovery, smallest, slowest),
/// Maximum = install.wim /Compress:max (the port's), Fast = install.wim /Compress:fast.</summary>
[System.Text.Json.Serialization.JsonConverter(typeof(System.Text.Json.Serialization.JsonStringEnumConverter<IsoCompression>))]
public enum IsoCompression { Recovery, Maximum, Fast }

/// <summary>The Build settings step's switches (plan docs/plans/2026-11-20-iso-builder-wizard.md, Build settings): the
/// final compression; Turbo = the Windows features removed in one DISM call, each read back; CleanLeftovers = the
/// image's leftover data (<see cref="IsoPlan.Leftovers"/>) removed unless servicing is pending; LeaveOutNetFx3Files =
/// sources\sxs not on the ISO. All off by default, compression Maximum.</summary>
public sealed record IsoBuildSettings
{
    public IsoCompression Compression { get; init; } = IsoCompression.Maximum;
    public bool Turbo { get; init; }
    public bool CleanLeftovers { get; init; }
    public bool LeaveOutNetFx3Files { get; init; }

    public static string CompressionText(IsoCompression c) => c switch
    {
        IsoCompression.Recovery => "Recovery ESD (smallest, slowest)",
        IsoCompression.Fast => "Fast WIM (largest, quickest)",
        _ => "Maximum WIM",
    };

    /// <summary>The settings as Review's lines.</summary>
    public IReadOnlyList<string> Lines() =>
    [
        $"Compression: {CompressionText(Compression)}",
        $"Turbo feature removal: {OnOff(Turbo)}",
        $"Remove leftover image data: {OnOff(CleanLeftovers)}",
        $".NET 3.5's setup files on the ISO: {(LeaveOutNetFx3Files ? "Left out" : "Kept")}",
    ];

    private static string OnOff(bool on) => on ? "On" : "Off";
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

    /// <summary>The build's ordered steps (New-AkariIsoPlan) for the picked <paramref name="groups"/>.</summary>
    /// <remarks>The groups' lists add the removal steps, and the settings, files and boot.wim steps come only when a
    /// group has some. .NET 3.5 and the component store cleanup come right after the apps, before any feature,
    /// capability or package is removed: those leave operations pending, and DISM refuses the cleanup then (a report
    /// showed it skipped, the image gigabytes larger). Minimal's pruning after the leftovers.</remarks>
    public static IReadOnlyList<IsoStep> Steps(IsoChoices c, IReadOnlyList<IsoGroup>? groups = null)
    {
        var s = new List<IsoStep>();
        void Add(string id, string text) => s.Add(new IsoStep(id, text));
        var g = groups ?? [];
        Add("Adk", "Getting the ISO tool ready (Windows ADK)");
        Add("Mount", $"Mounting {c.Edition}");
        if (List(c.Apps).Count > 0 || List(c.AppPatterns).Count > 0) Add("Apps", "Removing apps");
        Add("NetFx3", "Adding .NET Framework 3.5");
        Add("Cleanup", "Cleaning up the component store");
        if (List(c.Features).Count > 0 || g.Any(x => x.Features.Count > 0)) Add("Features", "Removing Windows features");
        if (List(c.Capabilities).Count > 0 || g.Any(x => x.Capabilities.Count > 0)) Add("Capabilities", "Removing optional features (capabilities)");
        if (List(c.Packages).Count > 0 || g.Any(x => x.Packages.Count > 0)) Add("Packages", "Removing OS packages");
        if (g.Any(x => x.Registry.Count > 0 || x.RemoveKeys.Count > 0)) Add("Registry", "Writing settings into the image's registry");
        if (c.Bake is { Count: > 0 } || (c.FirstSignIn && !string.IsNullOrEmpty(c.AkariExe))) Add("Bake", "Writing the AkariOS settings into the image");
        if (g.Any(x => x.Remove.Count > 0)) Add("Files", "Removing files from the image");
        if (!string.IsNullOrEmpty(c.AkariExe)) Add("AkariOS", "Adding AkariOS to the image");
        if (c.Settings.CleanLeftovers) Add("Leftovers", "Removing leftover image data");
        if (g.Any(x => x.PruneComponentStore)) Add("Prune", "Pruning the component store (Minimal: no updates or repairs afterwards)");
        Add("Commit", "Saving the image");
        Add("Compress", c.Settings.Compression switch
        {
            IsoCompression.Recovery => "Compressing install.esd (recovery compression)",
            IsoCompression.Fast => "Compressing install.wim (fast compression)",
            _ => "Compressing install.wim",
        });
        if (g.Any(x => x.Boot.Count > 0)) Add("Boot", "Skipping the Windows 11 requirements in setup (boot.wim)");
        if (c.Unattend is { Length: > 0 }) Add("Answer", "Adding the answer file (autounattend.xml)");
        if (c.Settings.LeaveOutNetFx3Files) Add("NoSxs", "Leaving .NET Framework 3.5's setup files off the ISO");
        Add("Iso", "Building the ISO");
        Add("Tidy", "Removing the work folder");
        return s;
    }

    /// <summary>Remove leftover image data's allow-list, paths under the mounted image (the last part may hold
    /// wildcards): downloaded updates, temp files, archived CBS and DISM logs, Windows Error Reporting's queues, crash
    /// dumps. Nothing a running Windows needs; kept whole while the image has pending servicing (<see cref="PendingXml"/>).</summary>
    public static IReadOnlyList<string> Leftovers { get; } =
    [
        @"Windows\SoftwareDistribution\Download\*",
        @"Windows\Temp\*",
        @"Windows\Logs\CBS\*.cab",
        @"Windows\Logs\CBS\CbsPersist_*.log",
        @"Windows\Logs\DISM\*.bak",
        @"ProgramData\Microsoft\Windows\WER\ReportQueue\*",
        @"ProgramData\Microsoft\Windows\WER\ReportArchive\*",
        @"ProgramData\Microsoft\Windows\WER\Temp\*",
        @"Windows\Minidump\*",
        @"Windows\MEMORY.DMP",
        @"Windows\LiveKernelReports\*.dmp",
    ];

    /// <summary>The image's pending servicing marker: while it is there, leftover data stays.</summary>
    public const string PendingXml = @"Windows\WinSxS\pending.xml";

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
