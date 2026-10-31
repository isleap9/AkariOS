using System.Management;
using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Machine;

public enum Chassis { Desktop, Laptop }

/// <summary>A display adapter's driver key (Class\{4d36e968-...}\0000): per-GPU Tweaks write under Path.</summary>
public sealed record Gpu(string Path, string Name, string Vendor);

/// <summary>What this PC is (src/Core/System.ps1), for Requires and for Tweaks.</summary>
public interface ISystemInfo
{
    /// <summary>The Windows build (Windows 11 from 22000).</summary>
    int Build { get; }

    /// <summary>The registry's EditionID: Core* = Home; Professional, Enterprise, ... ('' when it can't be read).</summary>
    string Edition { get; }

    Chassis Chassis { get; }

    IReadOnlyList<Gpu> Gpus { get; }

    /// <summary>The display adapters' device instance ids (PCI\VEN_...), for values under Enum\&lt;id&gt;.</summary>
    IReadOnlyList<string> GpuDevices { get; }
}

/// <summary>The WMI reads: the chassis types, the display devices. The real one is <see cref="WmiHardware"/>.</summary>
public interface IHardware
{
    IReadOnlyList<int> ChassisTypes();

    IReadOnlyList<string> DisplayDeviceIds();
}

/// <summary>
/// This PC through the registry engine (the edition, the GPUs' driver keys: tests point it at a test key) and
/// <see cref="IHardware"/> (WMI). Each is read once, as the PowerShell app reads the chassis once.
/// </summary>
public sealed partial class MachineInfo : ISystemInfo
{
    public const string GpuClass = @"HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}";

    // portable, laptop, notebook, hand held, docking station, sub notebook, expansion chassis... (SMBIOS chassis types)
    private static readonly int[] Portable = [8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32];

    private readonly Lazy<string> _edition;
    private readonly Lazy<Chassis> _chassis;
    private readonly Lazy<IReadOnlyList<Gpu>> _gpus;
    private readonly Lazy<IReadOnlyList<string>> _devices;

    public MachineInfo(RegistryEngine registry, IHardware hardware, int? build = null)
    {
        Build = build ?? Environment.OSVersion.Version.Build;
        _edition = new(() => PsSemantics.Text(registry.GetValue(@"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "EditionID")) ?? "");
        _chassis = new(() => Safe(hardware.ChassisTypes).Any(Portable.Contains) ? Chassis.Laptop : Chassis.Desktop);
        _gpus = new(() => ReadGpus(registry));
        _devices = new(() => Safe(hardware.DisplayDeviceIds));
    }

    public int Build { get; }
    public string Edition => _edition.Value;
    public Chassis Chassis => _chassis.Value;
    public IReadOnlyList<Gpu> Gpus => _gpus.Value;
    public IReadOnlyList<string> GpuDevices => _devices.Value;

    private static IReadOnlyList<T> Safe<T>(Func<IReadOnlyList<T>> read)
    {
        try { return read(); }
        catch (Exception e) when (e is ManagementException or System.Runtime.InteropServices.COMException or UnauthorizedAccessException) { return []; }
    }

    [GeneratedRegex(@"^\d{4}$")]
    private static partial Regex AdapterKey();

    private static List<Gpu> ReadGpus(RegistryEngine reg) =>
        reg.SubKeys(GpuClass).Where(k => AdapterKey().IsMatch(k)).Order(StringComparer.Ordinal).Select(k =>
        {
            var path = $@"{GpuClass}\{k}";
            var provider = PsSemantics.Text(reg.GetValue(path, "ProviderName")) ?? "";
            var desc = PsSemantics.Text(reg.GetValue(path, "DriverDesc")) ?? "";
            return new Gpu(path, desc, VendorOf($"{provider} {desc}"));
        }).ToList();

    /// <summary>NVIDIA, AMD, Intel or Other from a driver's provider and description (Get-AkariGpus). Pure.</summary>
    public static string VendorOf(string text) =>
        Regex.IsMatch(text, "NVIDIA", RegexOptions.IgnoreCase) ? "NVIDIA"
        : Regex.IsMatch(text, @"\bAMD\b|\bATI\b|Advanced Micro|Radeon", RegexOptions.IgnoreCase) ? "AMD"
        : Regex.IsMatch(text, "Intel", RegexOptions.IgnoreCase) ? "Intel"
        : "Other";
}

/// <summary>The real WMI reads (Win32_SystemEnclosure, Win32_PnPEntity of class Display).</summary>
public sealed class WmiHardware : IHardware
{
    public WmiHardware() => SystemGuard.Check("WMI");

    public IReadOnlyList<int> ChassisTypes()
    {
        using var s = new ManagementObjectSearcher("SELECT ChassisTypes FROM Win32_SystemEnclosure");
        var types = new List<int>();
        foreach (var o in s.Get())
            using (o)
                if (o["ChassisTypes"] is ushort[] t) types.AddRange(t.Select(x => (int)x));
        return types;
    }

    public IReadOnlyList<string> DisplayDeviceIds()
    {
        using var s = new ManagementObjectSearcher("SELECT DeviceID FROM Win32_PnPEntity WHERE PNPClass = 'Display'");
        var ids = new List<string>();
        foreach (var o in s.Get())
            using (o)
                if (o["DeviceID"] is string id) ids.Add(id);
        return ids;
    }
}
