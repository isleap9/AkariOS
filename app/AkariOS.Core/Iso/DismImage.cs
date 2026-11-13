using System.Runtime.InteropServices;
using AkariOS.Core.Apps;
using AkariOS.Core.Machine;

namespace AkariOS.Core.Iso;

/// <summary>
/// The real <see cref="IImage"/> (guarded): the DISM API (dismapi.dll, as the DISM cmdlets) for a WIM's editions,
/// mount, commit / discard, mount point cleanup and a mounted image's features, capabilities and packages (read and
/// removed); dism.exe /English through <see cref="IExe"/> for the rest, as the port: export (fast / max, a .swm's parts),
/// the provisioned apps (listed and removed), the NonRemovable policy, .NET 3.5, component cleanup.
/// </summary>
public sealed partial class DismImage : IImage
{
    private readonly IExe _exe;
    private readonly string _dism;

    public DismImage(IExe exe, string windows)
    {
        SystemGuard.Check("DISM image");
        _exe = exe;
        _dism = Path.Combine(windows, "System32", "dism.exe");
    }

    // ---- pure parts

    /// <summary>dism /Get-ProvisionedAppxPackages /English's list: DisplayName and PackageName of each block.</summary>
    public static IReadOnlyList<ImageApp> Provisioned(string output)
    {
        var list = new List<ImageApp>();
        string? name = null;
        foreach (var line in output.Split('\n'))
        {
            var cut = line.IndexOf(" : ", StringComparison.Ordinal);
            if (cut < 0) continue;
            var key = line[..cut].Trim();
            var value = line[(cut + 3)..].Trim();
            if (key == "DisplayName") name = value;
            else if (key == "PackageName" && name is not null) { list.Add(new ImageApp(name, value)); name = null; }
        }
        return list;
    }

    /// <summary>Export-WindowsImage's arguments for dism.exe: a .swm's other parts through /SWMFile.</summary>
    public static IReadOnlyList<string> ExportArgs(string source, int index, string dest, string compression)
    {
        var a = new List<string> { "/Export-Image", $"/SourceImageFile:{source}" };
        if (source.EndsWith(".swm", StringComparison.OrdinalIgnoreCase)) a.Add($"/SWMFile:{Path.Combine(Path.GetDirectoryName(source) ?? "", "install*.swm")}");
        a.AddRange([$"/SourceIndex:{index}", $"/DestinationImageFile:{dest}", $"/Compress:{compression}"]);
        return a;
    }

    private const int RebootRequired = 3010;

    /// <summary>A DISM API result as dism.exe's exit code: 0 done, 3010 done with a restart due, else the HRESULT.</summary>
    public static int Code(int hr) => hr switch
    {
        RebootRequired => RebootRequired,
        >= 0 => 0,
        unchecked((int)0x80070BC2) => RebootRequired,
        _ => hr,
    };

    /// <summary>An image's architecture as Get-WindowsImage names it.</summary>
    public static string Architecture(int a) => a switch { 0 => "x86", 5 => "ARM", 9 => "x64", 12 => "ARM64", _ => a.ToString(System.Globalization.CultureInfo.InvariantCulture) };

    // ---- dism.exe

    private ExeResult Run(IEnumerable<string> arguments) => _exe.Run(_dism, IsoBuild.JoinArgs(["/English", .. arguments]));

    public int Dism(IReadOnlyList<string> arguments) => Run(arguments).ExitCode;

    public void Export(string source, int index, string dest, string compression)
    {
        var r = Run(ExportArgs(source, index, dest, compression));
        if (r.ExitCode != 0) throw new InvalidOperationException($"DISM could not export the image (exit code {r.ExitCode}): {LastLine(r.Output)}");
    }

    public IReadOnlyList<ImageApp> ProvisionedApps(string mount)
    {
        var r = Run([$"/Image:{mount}", "/Get-ProvisionedAppxPackages"]);
        if (r.ExitCode != 0) throw new InvalidOperationException($"DISM could not list the image's apps (exit code {r.ExitCode}): {LastLine(r.Output)}");
        return Provisioned(r.Output);
    }

    private static string LastLine(string output) => output.Split('\n').Select(l => l.Trim()).LastOrDefault(l => l.Length > 0) ?? "";

    // ---- the DISM API

    // DismImageInfo, packed to 1 byte (x64): ImageType 0, ImageIndex 4, ImageName 8, ImageDescription 16, ImageSize 24,
    // Architecture 32, ProductName 36, EditionId 44, InstallationType 52, Hal 60, ProductType 68, ProductSuite 76,
    // MajorVersion 84, MinorVersion 88, Build 92, SpBuild 96, SpLevel 100, Bootable 104, SystemRoot 108, Language 116,
    // LanguageCount 124, DefaultLanguageIndex 128, CustomizedInfo 132: 140 bytes
    private const int ImageInfoSize = 140;

    // DismPackage: PackageName 0, PackageState 8, ReleaseType 12, InstallTime (SYSTEMTIME) 16: 32 bytes
    private const int PackageSize = 32;

    public IReadOnlyList<WimImage> Images(string wim) => DismApi.Locked(() =>
    {
        DismApi.Check(DismGetImageInfo(wim, out var info, out var count));
        try
        {
            var list = new List<WimImage>((int)count);
            for (var i = 0; i < count; i++)
            {
                var at = info + i * ImageInfoSize;
                int Int(int offset) => Marshal.ReadInt32(at, offset);
                var version = $"{Int(84)}.{Int(88)}.{Int(92)}.{Int(96)}";
                list.Add(new WimImage(Int(4), Marshal.PtrToStringUni(Marshal.ReadIntPtr(at, 8)) ?? "", version, Architecture(Int(32))));
            }
            return list;
        }
        finally { DismApi.DismDelete(info); }
    });

    public void Mount(string wim, int index, string mount) =>
        DismApi.Locked(() => DismApi.Check(DismMountImage(wim, mount, (uint)index, null, 0, 0, 0, 0, 0)));

    public void Commit(string mount) => DismApi.Locked(() => DismApi.Check(DismUnmountImage(mount, 0, 0, 0, 0)));

    public void Discard(string mount)
    {
        try { DismApi.Locked(() => DismUnmountImage(mount, 1, 0, 0, 0)); }
        catch (Exception e) when (e is InvalidOperationException or DllNotFoundException or EntryPointNotFoundException) { }
        try { DismApi.Locked(DismCleanupMountpoints); }
        catch (Exception e) when (e is InvalidOperationException or DllNotFoundException or EntryPointNotFoundException) { }
    }

    public IReadOnlyList<DismItem> Features(string mount) => DismApi.Session(mount, s =>
    {
        DismApi.Check(DismApi.DismGetFeatures(s, null, 0, out var items, out var count));
        return (IReadOnlyList<DismItem>)DismApi.Items(items, count, DismApi.FeatureStateName);
    });

    public IReadOnlyList<DismItem> Capabilities(string mount) => DismApi.Session(mount, s =>
    {
        DismApi.Check(DismApi.DismGetCapabilities(s, out var items, out var count));
        return (IReadOnlyList<DismItem>)DismApi.Items(items, count, DismApi.CapabilityStateName);
    });

    public IReadOnlyList<DismItem> Packages(string mount) => DismApi.Session(mount, s =>
    {
        DismApi.Check(DismGetPackages(s, out var items, out var count));
        return (IReadOnlyList<DismItem>)DismApi.Items(items, count, DismApi.CapabilityStateName, PackageSize);
    });

    public int Remove(string mount, string kind, string name) => Code(DismApi.Session(mount, s => kind switch
    {
        "Feature" => DismApi.DismDisableFeature(s, name, null, 1, 0, 0, 0),
        "Capability" => DismApi.DismRemoveCapability(s, name, 0, 0, 0),
        "Package" => DismRemovePackage(s, name, 1, 0, 0, 0),
        _ => throw new ArgumentException($"not a removal kind: {kind}", nameof(kind)),
    }));

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismGetImageInfo(string imageFilePath, out nint imageInfo, out uint count);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismMountImage(string imageFilePath, string mountPath, uint imageIndex, string? imageName, int imageIdentifier, uint flags, nint cancelEvent, nint progress, nint userData);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismUnmountImage(string mountPath, uint flags, nint cancelEvent, nint progress, nint userData);

    [LibraryImport("dismapi.dll")]
    private static partial int DismCleanupMountpoints();

    [LibraryImport("dismapi.dll")]
    private static partial int DismGetPackages(uint session, out nint package, out uint count);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismRemovePackage(uint session, string identifier, int packageIdentifier, nint cancelEvent, nint progress, nint userData);
}
