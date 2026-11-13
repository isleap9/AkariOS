using AkariOS.Core.Iso;

namespace AkariOS.Core.Tests;

/// <summary>DismImage's pure parts (the real one is guarded): dism.exe's provisioned app list read, the export
/// arguments, a DISM API result as the port's exit codes, an image's version and architecture.</summary>
public sealed class DismImageTests
{
    [Fact]
    public void Reads_the_provisioned_apps_dism_lists()
    {
        var apps = DismImage.Provisioned(File.ReadAllText(Path.Combine(Repo.Root, "tests", "Fixtures", "Iso", "provisioned-apps.txt")));
        Assert.Equal(6, apps.Count);
        Assert.Equal(new ImageApp("Clipchamp.Clipchamp", "Clipchamp.Clipchamp_4.3.10120.0_neutral_~_yxz26nhyzhsrt"), apps[0]);
        Assert.Equal(new ImageApp("MicrosoftWindows.Client.WebExperience", "MicrosoftWindows.Client.WebExperience_525.31002.150.0_x64__cw5n1h2txyewy"), apps[^1]);
    }

    [Fact]
    public void Reads_nothing_from_an_empty_list() => Assert.Empty(DismImage.Provisioned("The operation completed successfully.\r\n"));

    [Fact]
    public void Exports_one_image_with_its_compression()
    {
        Assert.Equal(["/Export-Image", @"/SourceImageFile:D:\a\install.esd", "/SourceIndex:6", @"/DestinationImageFile:D:\w\install.wim", "/Compress:fast"],
            DismImage.ExportArgs(@"D:\a\install.esd", 6, @"D:\w\install.wim", "fast"));
        Assert.Equal(["/Export-Image", @"/SourceImageFile:D:\a\install.swm", @"/SWMFile:D:\a\install*.swm", "/SourceIndex:1", @"/DestinationImageFile:D:\w\install.wim", "/Compress:max"],
            DismImage.ExportArgs(@"D:\a\install.swm", 1, @"D:\w\install.wim", "max"));
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, 0)]
    [InlineData(3010, 3010)]
    [InlineData(unchecked((int)0x80070BC2), 3010)]
    [InlineData(unchecked((int)0x800F080C), unchecked((int)0x800F080C))]
    public void Gives_a_removal_the_ports_exit_codes(int hr, int code) => Assert.Equal(code, DismImage.Code(hr));

    [Fact]
    public void Quotes_an_iso_path_for_wql() => Assert.Equal(@"'D:\\isos\\it\'s.iso'", WmiDiskImage.Literal(@"D:\isos\it's.iso"));

    private sealed class NoExe : Machine.IExe
    {
        public Machine.ExeResult Run(string path, string arguments, bool wait = true, bool capture = true) => throw new NotSupportedException();
    }

    [Fact]
    public void The_real_parts_refuse_to_run_under_test()
    {
        Assert.Throws<InvalidOperationException>(() => new DismImage(new NoExe(), @"C:\Windows"));
        Assert.Throws<InvalidOperationException>(() => new OfflineHives());
        Assert.Throws<InvalidOperationException>(() => new WmiDiskImage());
        Assert.Throws<InvalidOperationException>(() => IsoParts.Live(null!, null!, null!, new NoExe(), null!, null!, new MemoryLog()));
    }

    [Fact]
    public void Loads_the_hives_under_hklm_akariiso() => Assert.Equal("AkariIso_SOFTWARE", OfflineHives.KeyName("SOFTWARE"));

    [Theory]
    [InlineData(9, "x64")]
    [InlineData(12, "ARM64")]
    [InlineData(0, "x86")]
    [InlineData(5, "ARM")]
    [InlineData(7, "7")]
    public void Names_an_architecture_as_get_windowsimage(int a, string name) => Assert.Equal(name, DismImage.Architecture(a));
}
