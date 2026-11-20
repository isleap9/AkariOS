using AkariOS.App.ViewModels;
using AkariOS.Core.Unattend;

namespace AkariOS.App.Tests;

/// <summary>
/// Install USB (src/UI/Unattend.ps1) on <see cref="UnattendViewModel"/>: his form started from the defaults and this
/// PC, Open file, Reset, Save to a drive (the test's temp folders as drives) or a folder, with the questions before a
/// disk wipe, a drive without Windows setup and an existing file; each section's "Changed from the default".
/// </summary>
public sealed class UnattendTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private string Folder(string name)
    {
        var d = Path.Combine(_h.Dir, name);
        Directory.CreateDirectory(d);
        return d + @"\";
    }

    private static string Fixture(string name) => Path.Combine(Core.Tests.Repo.Root, "tests", "Fixtures", "Unattend", name + ".xml");

    /// <summary>The page with a Windows setup USB and a plain stick (the setup one first in the list).</summary>
    private (AppTest T, UnattendViewModel U, string Usb, string Stick) Opened()
    {
        var t = _h.Make();
        var (usb, stick) = (Folder("usb"), Folder("stick"));
        t.Drives.Drives.Add(new SetupDrive(stick, "STICK", false));
        t.Drives.Drives.Add(new SetupDrive(usb, "WIN11", true));
        t.Unattend.Shown();
        return (t, t.Unattend, usb, stick);
    }

    private static FormBinding Binding(UnattendViewModel u, string field) => u.Form.Bindings.First(b => b.Field == field);

    private static string Saved(string folder) => File.ReadAllText(Path.Combine(folder, "autounattend.xml"));

    [Fact]
    public void It_starts_from_the_defaults_and_this_PC_and_lists_the_setup_drive_first()
    {
        var (_, u, usb, _) = Opened();
        var f = u.Form.Fields();
        Assert.Equal("Unattended|it-IT|00000410|W. Europe Standard Time|Admin|Default",
            string.Join("|", f.Get("LanguageMode"), f.Get("UILanguage"), f.Get("Keyboard"), f.Get("TimeZone"), f.Get("AccountName0"), f.Get("PEMode")));
        Assert.Equal([$"{usb} WIN11 (Windows setup)", $@"{_h.Dir}\stick\ STICK"], u.DriveNames);
        Assert.Equal((0, true, true, $"{usb} WIN11 (Windows setup)", "The file goes to the root of the drive"),
            (u.DriveIndex, u.HasDriveChoice, u.CanSaveToUsb, u.DriveName, u.DriveNote));
        // every section of his page, each with a glyph, all on their defaults
        Assert.Contains(u.Sections, s => s.Title == "Region and language");
        Assert.Contains(u.Sections, s => s.Title == "XML markup for more components");
        Assert.All(u.Sections, s => Assert.Equal("Default", s.Status));
    }

    [Fact]
    public void A_section_says_when_it_differs_from_the_start_and_reset_asks_then_puts_it_back()
    {
        var (t, u, _, _) = Opened();
        var wifi = u.Sections.Single(s => s.Fields.Contains("WifiMode"));
        Binding(u, "WifiMode").Pick("Skip");
        Assert.Equal("Changed from the default", wifi.Status);
        Assert.Equal(1, u.Sections.Count(s => s.Changed));
        // a field inside a branch counts too
        Assert.Contains("WifiName", wifi.Fields);

        // Reset asks; Cancel keeps it
        await_(u.ResetAsync());
        Assert.Equal("The form goes back to the defaults and this PC's language, keyboard, region and time zone.", t.Dialogs.Asked[^1]);
        Assert.True(wifi.Changed);
        t.Dialogs.Answers.Enqueue("Reset");
        await_(u.ResetAsync());
        Assert.False(wifi.Changed);
        Assert.Equal("Interactive", u.Form.Fields().Get("WifiMode"));
    }

    private static void await_(Task task) => task.GetAwaiter().GetResult();

    [Fact]
    public async Task A_file_that_wipes_a_disk_asks_first_and_No_saves_nothing()
    {
        var (t, u, usb, _) = Opened();
        Binding(u, "PEMode").Pick("Generated");
        await u.SaveToUsbAsync();
        Assert.StartsWith("This file wipes a disk without asking", t.Dialogs.Asked.Single());
        Assert.False(File.Exists(Path.Combine(usb, "autounattend.xml")));
    }

    [Fact]
    public async Task The_generators_check_shows_under_the_drive_bar_and_nothing_is_saved()
    {
        var (t, u, usb, _) = Opened();
        Binding(u, "AccountGroup0").Pick("Users");
        await u.SaveToUsbAsync();
        Assert.Equal(("Must have at least one administrator account.", true), (u.Error, u.HasError));
        Assert.Empty(t.Dialogs.Asked);
        Assert.False(File.Exists(Path.Combine(usb, "autounattend.xml")));
    }

    [Fact]
    public async Task It_saves_to_the_setup_drive_without_asking_opens_it_and_the_file_reads_back()
    {
        var (t, u, usb, _) = Opened();
        await u.SaveToUsbAsync();
        Assert.Equal("", u.Error);
        Assert.Empty(t.Dialogs.Asked);
        Assert.Equal([usb], t.Open.Opened);
        Assert.Equal($"autounattend.xml saved: {usb}autounattend.xml", t.Toasts[0]);
        var back = UnattendQuery.FromXml(Saved(usb))!;
        Assert.Equal(("Admin", "it-IT"), (back.Get("AccountName0"), back.Get("UILanguage")));
        Assert.Equal(UnattendFile.Make(u.Form.Fields()), File.ReadAllBytes(Path.Combine(usb, "autounattend.xml")));
    }

    [Fact]
    public async Task A_drive_without_Windows_setup_or_with_a_file_already_asks_first()
    {
        var (t, u, _, stick) = Opened();
        u.DriveIndex = 1;
        Assert.Equal("The file goes to the root of the drive", u.DriveNote);
        await u.SaveToUsbAsync();
        Assert.StartsWith($"{stick} has no Windows setup on it", t.Dialogs.Asked.Single());
        Assert.False(File.Exists(Path.Combine(stick, "autounattend.xml")));

        t.Dialogs.Answers.Enqueue("Save anyway");
        await u.SaveToUsbAsync();
        Assert.True(File.Exists(Path.Combine(stick, "autounattend.xml")));

        t.Dialogs.Answers.Enqueue("Save anyway");
        File.WriteAllText(Path.Combine(stick, "autounattend.xml"), "old");
        await u.SaveToUsbAsync();
        Assert.StartsWith($"{stick} already has an autounattend.xml", t.Dialogs.Asked[^1]);
        Assert.Equal("old", Saved(stick));
    }

    [Fact]
    public async Task No_drive_says_so_and_a_folder_takes_the_file()
    {
        var t = _h.Make();
        t.Drives.Fail = true;
        var u = t.Unattend;
        u.Shown();
        Assert.Equal((false, "No Windows setup USB found", "Plug one in, then refresh"), (u.CanSaveToUsb, u.DriveName, u.DriveNote));
        await u.SaveToUsbAsync();
        Assert.Equal("No USB drive found: plug one in and press Refresh, or save to a folder.", u.Error);

        // the folder picker cancelled: nothing
        await u.SaveToFolderAsync();
        Assert.Empty(t.Open.Opened);
        t.Picker.FolderPath = Folder("folder");
        await u.SaveToFolderAsync();
        Assert.Equal("", u.Error);
        Assert.True(File.Exists(Path.Combine(t.Picker.FolderPath, "autounattend.xml")));
        Assert.Equal([t.Picker.FolderPath], t.Open.Opened);

        await u.SaveToFolderAsync();
        Assert.StartsWith("This folder already has an autounattend.xml", t.Dialogs.Asked.Single());

        // a drive plugged in, Refresh finds it
        t.Drives.Fail = false;
        t.Drives.Drives.Add(new SetupDrive(Folder("usb"), "WIN11", true));
        u.RefreshDrivesCommand.Execute(null);
        Assert.True(u.CanSaveToUsb);
    }

    [Fact]
    public async Task A_file_from_his_site_opens_and_the_form_saves_the_very_same_file()
    {
        var (t, u, usb, _) = Opened();
        t.Picker.XmlPath = Fixture("2-unattended");
        await u.OpenAsync();
        Assert.Equal("Home & Co", Binding(u, "WifiName").Value);
        Assert.Equal(3, u.Form.Accounts.Shown);
        Assert.Contains(u.Sections, s => s.Changed);
        await u.SaveToUsbAsync();
        Assert.Equal(Canonical(File.ReadAllText(t.Picker.XmlPath)), Canonical(Saved(usb)));
    }

    [Fact]
    public async Task A_file_it_cant_read_says_so()
    {
        var (t, u, _, _) = Opened();
        var other = Path.Combine(_h.Dir, "other.xml");
        File.WriteAllText(other, "<unattend xmlns=\"urn:schemas-microsoft-com:unattend\"/>");
        t.Picker.XmlPath = other;
        await u.OpenAsync();
        Assert.StartsWith("This file wasn't made by AkariOS", t.Dialogs.Asked.Single());
    }

    [Fact]
    public async Task The_iso_builder_gets_the_forms_file_even_when_the_page_never_opened()
    {
        var t = _h.Make();
        var (bytes, error) = await t.Unattend.IsoAnswerAsync();
        Assert.Null(error);
        Assert.Equal("it-IT", UnattendQuery.FromXml(System.Text.Encoding.ASCII.GetString(bytes!))!.Get("UILanguage"));
        // a disk wipe asks: Cancel = neither
        Binding(t.Unattend, "PEMode").Pick("Generated");
        Assert.Equal((null, null), await t.Unattend.IsoAnswerAsync());
    }

    private static string Canonical(string xml)
    {
        var d = new System.Xml.XmlDocument();
        d.LoadXml(xml);
        var ns = new System.Xml.XmlNamespaceManager(d.NameTable);
        ns.AddNamespace("s", UnattendQuery.Site);
        foreach (var n in d.SelectNodes("//comment()")!.Cast<System.Xml.XmlNode>().ToList()) n.ParentNode!.RemoveChild(n);
        foreach (var n in d.SelectNodes("//s:Commit", ns)!.Cast<System.Xml.XmlNode>().ToList()) n.ParentNode!.RemoveChild(n);
        foreach (var n in d.SelectNodes("//s:Build", ns)!.Cast<System.Xml.XmlNode>().ToList()) if (!n.HasChildNodes) n.ParentNode!.RemoveChild(n);
        return d.OuterXml;
    }
}
