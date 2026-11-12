using AkariOS.Core.Registry;
using AkariOS.Core.Unattend;
using Schneegans.Unattend;

namespace AkariOS.Core.Tests;

/// <summary>The Unattend Generator (N9): Schneegans' vendored library and AkariOS.Core/Unattend.</summary>
public sealed class UnattendTests
{
    [Fact]
    public void His_generator_runs_on_the_shared_data_files()
    {
        var bytes = UnattendGenerator.Serialize(new UnattendGenerator().GenerateXml(Configuration.Default));
        var text = System.Text.Encoding.ASCII.GetString(bytes);
        Assert.StartsWith("<?xml version=\"1.0\" encoding=\"utf-8\"?>", text);
        Assert.Contains("urn:schemas-microsoft-com:unattend", text);
    }

    private const string Profile = @"HKCU:\Control Panel\International\User Profile";

    private static PcRegion Read(TestKey key) =>
        new RegistryPcRegion(new RegistryEngine(key.Paths), () => ("en-GB", "it-IT", "W. Europe Standard Time")).Read();

    [Fact]
    public void This_PC_s_keyboard_is_the_first_language_s_first_input_method_and_its_region_the_home_location()
    {
        using var key = new TestKey();
        var r = new RegistryEngine(key.Paths);
        r.SetValue(Profile, "Languages", new[] { "en-US", "it-IT" }, "MultiString");
        r.SetValue(Profile + @"\en-US", "CachedLanguageName", "@Winlangdb.dll,-1121", "String");
        r.SetValue(Profile + @"\en-US", "0409:00000409", 2, "DWord");
        r.SetValue(Profile + @"\en-US", "0409:0000080A", 1, "DWord");
        r.SetValue(Profile + @"\it-IT", "0410:00000410", 1, "DWord");
        r.SetValue(@"HKCU:\Control Panel\International\Geo", "Nation", "118", "String");

        Assert.Equal(new PcRegion("en-GB", "it-IT", "0000080a", "118", "W. Europe Standard Time"), Read(key));
    }

    [Fact]
    public void An_IME_or_nothing_read_is_the_US_keyboard_and_no_region_is_the_United_States()
    {
        using var key = new TestKey();
        var r = new RegistryEngine(key.Paths);
        Assert.Equal(new PcRegion("en-GB", "it-IT", "00000409", "244", "W. Europe Standard Time"), Read(key));

        r.SetValue(Profile, "Languages", new[] { "ja" }, "MultiString");
        r.SetValue(Profile + @"\ja", "0411:{03B5835F-F03C-411B-9CE2-AA23E1171E36}{A76C93D9-5523-4E90-AAFA-4DB112F9AC76}", 1, "DWord");
        Assert.Equal("00000409", Read(key).Keyboard);
    }

    [Fact]
    public void Setup_drives_are_removable_ones_and_others_holding_Windows_setup_never_the_system_drive()
    {
        (string, DriveType, string)[] drives =
        [
            (@"C:\", DriveType.Fixed, "System"), (@"D:\", DriveType.Removable, "STICK"), (@"E:\", DriveType.Removable, "CCCOMA_X64"),
            (@"F:\", DriveType.Fixed, "USB SSD"), (@"G:\", DriveType.Fixed, "Data"), (@"H:\", DriveType.CDRom, "DVD"), (@"I:\", DriveType.Network, "Share"),
        ];
        string[] files = [@"E:\sources\install.esd", @"F:\sources\install.wim", @"C:\sources\install.wim", @"H:\sources\install.wim", @"I:\sources\install.swm"];
        var d = SetupDrives.Pick(drives, "c:", files.Contains);
        Assert.Equal(@"D:\,E:\,F:\", string.Join(",", d.Select(x => x.Root)));
        Assert.Equal("STICK:False,CCCOMA_X64:True,USB SSD:True", string.Join(",", d.Select(x => $"{x.Label}:{x.Setup}")));
    }

    [Fact]
    public void The_drive_list_puts_Windows_setup_drives_first_and_says_so()
    {
        var d = SetupDrives.Ordered([new(@"D:\", "STICK", false), new(@"E:\", "", true), new(@"F:\", "WIN11", true)]);
        Assert.Equal(@"E:\ (Windows setup)|F:\ WIN11 (Windows setup)|D:\ STICK", string.Join("|", d.Select(SetupDrives.Display)));
    }

    [Fact]
    public void Save_writes_autounattend_xml_in_the_folder_made_if_missing_and_returns_its_path()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"akari-usb-{Guid.NewGuid():N}", "usb");
        try
        {
            var p = UnattendSave.Save("<unattend/>"u8.ToArray(), dir);
            Assert.Equal(Path.Combine(dir, "autounattend.xml"), p);
            Assert.Equal("<unattend/>", File.ReadAllText(p));
            Assert.True(UnattendSave.Exists(dir));
            Assert.False(UnattendSave.Exists(Path.Combine(dir, "other")));
        }
        finally { Directory.Delete(Path.GetDirectoryName(dir)!, true); }
    }

    [Fact]
    public void The_live_drive_list_is_never_made_under_test() =>
        Assert.Throws<InvalidOperationException>(() => new LiveSetupDrives());

    [Fact]
    public void The_live_reader_is_never_made_under_test() =>
        Assert.Throws<InvalidOperationException>(() => RegistryPcRegion.Live(new RegistryEngine(new RedirectedRegistryPaths("x"))));
}
