using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Update;

namespace AkariOS.Core.Iso;

/// <summary>
/// A Windows image (the port's Get-AkariWimImages, Export- / Mount- / Save- / Undo-AkariWim, the image reads and
/// Invoke-AkariDism): the DISM API where it is public, dism.exe /English for the rest. The real one is
/// <see cref="DismImage"/>; tests record.
/// </summary>
public interface IImage
{
    /// <summary>The images in a .wim / .esd / .swm.</summary>
    IReadOnlyList<WimImage> Images(string wim);

    /// <summary>One image of <paramref name="source"/> into a new <paramref name="dest"/> (compression fast or max; a
    /// .swm's parts read too). Throws when it fails.</summary>
    void Export(string source, int index, string dest, string compression);

    /// <summary>Throws when it fails.</summary>
    void Mount(string wim, int index, string mount);

    /// <summary>Saves and unmounts. Throws when it fails.</summary>
    void Commit(string mount);

    /// <summary>Unmounts without saving and cleans up stale mount points; never throws.</summary>
    void Discard(string mount);

    /// <summary>The mounted image's provisioned apps (frameworks too).</summary>
    IReadOnlyList<ImageApp> ProvisionedApps(string mount);

    IReadOnlyList<DismItem> Features(string mount);

    /// <summary>Every capability with its state (Get-WindowsCapability's names).</summary>
    IReadOnlyList<DismItem> Capabilities(string mount);

    IReadOnlyList<DismItem> Packages(string mount);

    /// <summary>A feature (disabled, its payload removed), a capability or an OS package out of the mounted image:
    /// 0 = done, 3010 = done with a restart due, else the failure's code.</summary>
    int Remove(string mount, string kind, string name);

    /// <summary>dism.exe /English with these arguments: its exit code.</summary>
    int Dism(IReadOnlyList<string> arguments);
}

/// <summary>The mounted image's registry hives, loaded at HKLM\AkariIso_&lt;name&gt; (the port's reg.exe load /
/// unload). The real one is <see cref="OfflineHives"/>.</summary>
public interface IOfflineHives
{
    bool Load(string name, string file);

    bool Unload(string name);
}

/// <summary>The ISO mounted as a drive (Mount- / Dismount-AkariDiskImage). The real one is <see cref="WmiDiskImage"/>.</summary>
public interface IDiskImage
{
    /// <summary>Its root ('E:\').</summary>
    string Mount(string iso);

    void Dismount(string iso);
}

/// <summary>What a build reaches: the data files, the image, its hives (written through <see cref="Registry"/> on
/// HKLM:\AkariIso_…, a denied row or key as <see cref="Trusted"/>), the ISO drive, programs (takeown, icacls, adksetup,
/// oscdimg), downloads (the ADK), shortcuts, the log, the marker file (a mount left behind), folders, the output
/// drive's space, a pause (hive unload retries).</summary>
public sealed record IsoParts
{
    public required ISourceFiles Files { get; init; }
    public required IImage Image { get; init; }
    public required IOfflineHives Hives { get; init; }
    public required IDiskImage Disk { get; init; }
    public required RegistryEngine Registry { get; init; }
    public required ITrustedInstaller Trusted { get; init; }
    public required IExe Exe { get; init; }
    public required IHttp Http { get; init; }
    public required IShortcuts Shortcuts { get; init; }
    public required IAkariLog Log { get; init; }

    /// <summary>The marker file: %ProgramData%\AkariOS.Native\iso-mount.json.</summary>
    public required string Marker { get; init; }

    public required string Windows { get; init; }
    public required string ProgramFilesX86 { get; init; }
    public required string Temp { get; init; }

    /// <summary>The free bytes and file system of the drive holding a path (Get-AkariDriveInfo).</summary>
    public required Func<string, (long Free, string Format)> Drive { get; init; }

    public required Action<int> Sleep { get; init; }

    /// <summary>The native app's marker: %ProgramData%\AkariOS.Native\iso-mount.json.</summary>
    public static string DefaultMarker => Path.Combine(AkariPaths.MachineFolder, "iso-mount.json");

    /// <summary>The real parts (guarded): DISM, the hives, the ISO drive; the engine's registry (HKLM:\AkariIso_… as
    /// it is), TrustedInstaller, programs, downloads, shortcuts and log.</summary>
    public static IsoParts Live(ISourceFiles files, RegistryEngine registry, ITrustedInstaller trusted, IExe exe, IHttp http, IShortcuts shortcuts, IAkariLog log)
    {
        var windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        return new IsoParts
        {
            Files = files, Image = new DismImage(exe, windows), Hives = new OfflineHives(), Disk = new WmiDiskImage(), Registry = registry,
            Trusted = trusted, Exe = exe, Http = http, Shortcuts = shortcuts, Log = log, Marker = DefaultMarker, Windows = windows,
            ProgramFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), Temp = Path.GetTempPath(),
            Drive = path =>
            {
                var d = new DriveInfo(Path.GetPathRoot(Path.GetFullPath(path))!);
                return (d.AvailableFreeSpace, d.DriveFormat);
            },
            Sleep = Thread.Sleep,
        };
    }
}

/// <summary>An opened ISO: the work folder, its install image, the image's editions.</summary>
public sealed record IsoSource(IsoWork Work, string Image, IReadOnlyList<IsoEdition> Editions);

/// <summary>A build's end: the ISO's path, or why it failed.</summary>
public sealed record IsoResult(bool Ok, string? Path, string Message);
