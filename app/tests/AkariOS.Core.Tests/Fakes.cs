using AkariOS.Core.Machine;

namespace AkariOS.Core.Tests;

/// <summary>A made-up PC: Windows 11 Pro desktop with no GPU unless a test says otherwise.</summary>
internal sealed class FakeSystem : ISystemInfo
{
    public int Build { get; set; } = 26100;
    public string Edition { get; set; } = "Professional";
    public Chassis Chassis { get; set; } = Chassis.Desktop;
    public IReadOnlyList<Gpu> Gpus { get; set; } = [];
    public IReadOnlyList<string> GpuDevices { get; set; } = [];
}

internal sealed class FakeHardware : IHardware
{
    public int[] Chassis { get; set; } = [3];
    public string[] Devices { get; set; } = [];
    public int Reads { get; private set; }
    public Exception? Fail { get; set; }

    public IReadOnlyList<int> ChassisTypes()
    {
        Reads++;
        return Fail is null ? Chassis : throw Fail;
    }

    public IReadOnlyList<string> DisplayDeviceIds() => Fail is null ? Devices : throw Fail;
}
