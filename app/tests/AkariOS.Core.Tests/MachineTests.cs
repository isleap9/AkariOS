using System.Management;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

public sealed class MachineTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly RegistryEngine _reg;

    public MachineTests() => _reg = new RegistryEngine(_key.Paths);

    public void Dispose() => _key.Dispose();

    private void AddGpu(string key, string provider, string desc)
    {
        _reg.SetValue($@"{MachineInfo.GpuClass}\{key}", "ProviderName", provider, "String");
        _reg.SetValue($@"{MachineInfo.GpuClass}\{key}", "DriverDesc", desc, "String");
    }

    [Fact]
    public void Reads_the_edition_and_the_gpus_from_the_registry()
    {
        _reg.SetValue(@"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "EditionID", "Professional", "String");
        AddGpu("0001", "Intel Corporation", "Intel(R) UHD Graphics 770");
        AddGpu("0000", "NVIDIA", "NVIDIA GeForce RTX 4070");
        _reg.CreateKey($@"{MachineInfo.GpuClass}\Properties");
        var pc = new MachineInfo(_reg, new FakeHardware(), build: 26100);

        Assert.Equal(("Professional", 26100), (pc.Edition, pc.Build));
        Assert.Equal(["NVIDIA", "Intel"], pc.Gpus.Select(g => g.Vendor));
        Assert.Equal($@"{MachineInfo.GpuClass}\0000", pc.Gpus[0].Path);
        Assert.Equal("NVIDIA GeForce RTX 4070", pc.Gpus[0].Name);
    }

    [Fact]
    public void Nothing_to_read_is_empty()
    {
        var pc = new MachineInfo(_reg, new FakeHardware { Fail = new ManagementException("no WMI") });
        Assert.Equal("", pc.Edition);
        Assert.Empty(pc.Gpus);
        Assert.Equal(Chassis.Desktop, pc.Chassis);
        Assert.Empty(pc.GpuDevices);
        Assert.Equal(Environment.OSVersion.Version.Build, pc.Build);
    }

    [Theory]
    [InlineData(new[] { 3 }, Chassis.Desktop)]
    [InlineData(new[] { 10 }, Chassis.Laptop)]
    [InlineData(new[] { 3, 31 }, Chassis.Laptop)]
    [InlineData(new int[0], Chassis.Desktop)]
    public void The_chassis_is_read_once(int[] types, Chassis expected)
    {
        var hw = new FakeHardware { Chassis = types, Devices = [@"PCI\VEN_10DE&DEV_2786"] };
        var pc = new MachineInfo(_reg, hw);
        Assert.Equal(expected, pc.Chassis);
        Assert.Equal(expected, pc.Chassis);
        Assert.Equal(1, hw.Reads);
        Assert.Equal([@"PCI\VEN_10DE&DEV_2786"], pc.GpuDevices);
    }

    [Theory]
    [InlineData("NVIDIA NVIDIA GeForce GTX 1060", "NVIDIA")]
    [InlineData("Advanced Micro Devices, Inc. AMD Radeon RX 7800 XT", "AMD")]
    [InlineData("ATI Technologies Inc. ATI Radeon HD 5450", "AMD")]
    [InlineData("Intel Corporation Intel(R) Arc(TM) A770", "Intel")]
    [InlineData("Microsoft Microsoft Basic Display Adapter", "Other")]
    [InlineData("Lamdatech LAMD adapter", "Other")]
    public void Vendors_as_Get_AkariGpus_names_them(string text, string vendor) => Assert.Equal(vendor, MachineInfo.VendorOf(text));

    [Theory]
    [InlineData("Win11", null)]
    [InlineData("Win10", "needs Win10")]
    [InlineData("Desktop", null)]
    [InlineData("Laptop", "needs Laptop")]
    [InlineData("Pro", null)]
    [InlineData("Home", "needs Home")]
    [InlineData("NVIDIA", null)]
    [InlineData("AMD", "needs AMD")]
    [InlineData("Unknown", "needs Unknown")]
    public void Requirements_on_a_win11_pro_desktop_with_nvidia(string requires, string? reason)
    {
        var pc = new FakeSystem { Gpus = [new Gpu("x", "RTX", "NVIDIA")] };
        Assert.Equal(reason, Requirements.Check([requires], pc));
    }

    [Theory]
    [InlineData("Core", true, false)]
    [InlineData("CoreSingleLanguage", true, false)]
    [InlineData("Enterprise", false, true)]
    [InlineData("", false, false)]
    public void Home_and_pro(string edition, bool home, bool pro)
    {
        var pc = new FakeSystem { Edition = edition };
        Assert.Equal((home, pro), (Requirements.Met("Home", pc), Requirements.Met("Pro", pc)));
    }

    [Fact]
    public void The_first_unmet_requirement_is_the_reason()
    {
        var pc = new FakeSystem { Build = 19045, Chassis = Chassis.Laptop };
        Assert.Equal("needs Desktop", Requirements.Check(["Win10", "Desktop", "AMD"], pc));
        Assert.Null(Requirements.Check([], pc));
    }

    [Fact]
    public void Every_requirement_the_loader_takes_is_checked()
    {
        var pc = new FakeSystem();
        foreach (var r in Loader.Requirements) _ = Requirements.Met(r, pc);
        var loaded = new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load();
        Assert.Contains(loaded.Tweaks, t => t.Requires.Count > 0 && Requirements.Check(t, pc) is null);
    }

    [Fact]
    public void Nothing_real_can_be_made_in_a_test()
    {
        Assert.Throws<InvalidOperationException>(() => new WmiHardware());
        Assert.Throws<InvalidOperationException>(() => new ExplorerShell());
    }
}
