using System.IO;
using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Pages;
using AkariOS.Core.Unattend;
using static AkariOS.App.Tests.AppHarness;

namespace AkariOS.App.Tests;

/// <summary>
/// The Unattend Generator page (src/UI/Unattend.ps1), through AppHarness: his form, Open file, Reset, Save to a drive
/// (the test's temp folders as drives) or a folder, with the questions before a disk wipe, a drive without Windows
/// setup and an existing file.
/// </summary>
[Collection("Motion")]
public sealed class UnattendPageTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private string Folder(string name)
    {
        var d = Path.Combine(_h.Dir, name);
        Directory.CreateDirectory(d);
        return d + @"\";
    }

    private static string Fixture(string name) => Path.Combine(LookTests.RepoRoot(), "tests", "Fixtures", "Unattend", name + ".xml");

    /// <summary>The page with a Windows setup USB and a plain stick (the setup one first in the list).</summary>
    private (AppTest T, UnattendPage Page, string Usb, string Stick) Opened()
    {
        var t = _h.Make();
        var (usb, stick) = (Folder("usb"), Folder("stick"));
        t.Drives.Drives.Add(new SetupDrive(stick, "STICK", false));
        t.Drives.Drives.Add(new SetupDrive(usb, "WIN11", true));
        return (t, Show(t), usb, stick);
    }

    /// <summary>The tile: the page opened and built (no window here: PageFactory builds it as the window would).</summary>
    private static UnattendPage Show(AppTest t)
    {
        t.S.Shell.Open("Unattend Generator");
        PageFactory.For(t.S)("Unattend Generator");
        return t.S.Unattend!;
    }

    private static FormBinding Binding(UnattendPage p, string field) => p.Form.Bindings.First(b => b.Field == field);

    private static string Saved(string folder) => File.ReadAllText(Path.Combine(folder, "autounattend.xml"));

    [Fact]
    public void The_tile_opens_his_form_full_page_and_Back_goes_Home() => LookTests.OnSta(() =>
    {
        var (t, page, _, _) = Opened();
        var view = (FrameworkElement)PageFactory.For(t.S)("Unattend Generator");
        var texts = Texts(view);
        Assert.Contains("Region and language", texts);
        Assert.Contains("XML markup for more components", texts);
        Assert.DoesNotContain("Not in the native app yet", texts);
        Assert.Same(view, PageFactory.For(t.S)("Unattend Generator"));
        Click(All<Button>(view).Single(b => b.Content as string == "Back"));
        Assert.Equal("Home", t.S.Shell.Page);
    });

    [Fact]
    public void It_starts_from_the_defaults_and_this_PC_and_lists_the_setup_drive_first() => LookTests.OnSta(() =>
    {
        var (_, page, usb, _) = Opened();
        var f = page.Form.Fields();
        Assert.Equal("Unattended|it-IT|00000410|W. Europe Standard Time|Admin|Default",
            string.Join("|", f.Get("LanguageMode"), f.Get("UILanguage"), f.Get("Keyboard"), f.Get("TimeZone"), f.Get("AccountName0"), f.Get("PEMode")));
        Assert.Equal([$@"{usb} WIN11 (Windows setup)", @$"{_h.Dir}\stick\ STICK"], page.DriveNames);
    });

    [Fact]
    public void Picking_a_radio_in_the_view_shows_its_branch_and_counts_its_fields() => LookTests.OnSta(() =>
    {
        var (t, page, _, _) = Opened();
        var view = (FrameworkElement)PageFactory.For(t.S)("Unattend Generator");
        var generated = All<RadioButton>(view).Single(r => (r.Content as string ?? "").StartsWith("Generate a .cmd script"));
        var branch = (FrameworkElement)generated.Tag;
        Assert.Equal(Visibility.Collapsed, branch.Visibility);
        generated.IsChecked = true;
        Assert.Equal(Visibility.Visible, branch.Visibility);
        Assert.Equal("Unattended", page.Form.Fields().Get("PartitionMode"));
        Binding(page, "PEMode").Pick("Default");
        Assert.False(generated.IsChecked);
        Assert.Equal(Visibility.Collapsed, branch.Visibility);
    });

    [Fact]
    public void A_file_that_wipes_a_disk_asks_first_and_No_saves_nothing() => LookTests.OnSta(() =>
    {
        var (t, page, usb, _) = Opened();
        Binding(page, "PEMode").Pick("Generated");
        t.Answers.Enqueue("Cancel");
        page.SaveToUsb();
        Assert.StartsWith("This file wipes a disk without asking", t.Asked.Single());
        Assert.False(File.Exists(Path.Combine(usb, "autounattend.xml")));
    });

    [Fact]
    public void The_generator_s_check_shows_under_Save_and_nothing_is_saved() => LookTests.OnSta(() =>
    {
        var (t, page, usb, _) = Opened();
        Binding(page, "AccountGroup0").Pick("Users");
        page.SaveToUsb();
        Assert.Equal("Must have at least one administrator account.", page.Error);
        Assert.Empty(t.Asked);
        Assert.False(File.Exists(Path.Combine(usb, "autounattend.xml")));
    });

    [Fact]
    public void It_saves_to_the_setup_drive_without_asking_opens_it_and_the_file_reads_back() => LookTests.OnSta(() =>
    {
        var (t, page, usb, _) = Opened();
        page.SaveToUsb();
        Assert.Equal("", page.Error);
        Assert.Empty(t.Asked);
        Assert.Equal([usb], t.Opened);
        var back = UnattendQuery.FromXml(Saved(usb))!;
        Assert.Equal(("Admin", "it-IT"), (back.Get("AccountName0"), back.Get("UILanguage")));
        Assert.Equal(UnattendFile.Make(page.Form.Fields()), File.ReadAllBytes(Path.Combine(usb, "autounattend.xml")));
    });

    [Fact]
    public void A_drive_without_Windows_setup_or_with_a_file_already_asks_first() => LookTests.OnSta(() =>
    {
        var (t, page, _, stick) = Opened();
        page.DriveIndex = 1;
        t.Answers.Enqueue("Cancel");
        page.SaveToUsb();
        Assert.StartsWith($"{stick} has no Windows setup on it", t.Asked.Single());
        Assert.False(File.Exists(Path.Combine(stick, "autounattend.xml")));

        t.Answers.Enqueue("Save anyway");
        page.SaveToUsb();
        Assert.True(File.Exists(Path.Combine(stick, "autounattend.xml")));

        t.Answers.Enqueue("Save anyway");
        t.Answers.Enqueue("Cancel");
        File.WriteAllText(Path.Combine(stick, "autounattend.xml"), "old");
        page.SaveToUsb();
        Assert.StartsWith($"{stick} already has an autounattend.xml", t.Asked[^1]);
        Assert.Equal("old", Saved(stick));
    });

    [Fact]
    public void No_drive_says_so_and_a_folder_takes_the_file() => LookTests.OnSta(() =>
    {
        var t = _h.Make();
        t.Drives.Fail = true;
        var page = Show(t);
        page.SaveToUsb();
        Assert.Equal("No USB drive found: plug one in and press Refresh, or save to a folder.", page.Error);

        page.SaveToFolder();
        Assert.Empty(t.Opened);
        t.Picker.FolderPath = Folder("folder");
        page.SaveToFolder();
        Assert.True(File.Exists(Path.Combine(t.Picker.FolderPath, "autounattend.xml")));
        Assert.Equal([t.Picker.FolderPath], t.Opened);

        t.Answers.Enqueue("Cancel");
        page.SaveToFolder();
        Assert.StartsWith("This folder already has an autounattend.xml", t.Asked.Single());
    });

    [Fact]
    public void A_file_from_his_site_opens_and_the_form_saves_the_very_same_file() => LookTests.OnSta(() =>
    {
        var (t, page, usb, _) = Opened();
        t.Picker.XmlPath = Fixture("2-unattended");
        page.Open();
        Assert.Equal("Home & Co", Binding(page, "WifiName").Value);
        Assert.Equal(3, page.Form.Accounts.Shown);
        page.SaveToUsb();
        Assert.Equal(Canonical(File.ReadAllText(t.Picker.XmlPath)), Canonical(Saved(usb)));
    });

    [Fact]
    public void A_file_it_can_t_read_says_so_and_Reset_goes_back_to_the_start() => LookTests.OnSta(() =>
    {
        var (t, page, _, _) = Opened();
        var other = Path.Combine(_h.Dir, "other.xml");
        File.WriteAllText(other, "<unattend xmlns=\"urn:schemas-microsoft-com:unattend\"/>");
        t.Picker.XmlPath = other;
        page.Open();
        Assert.StartsWith("This file wasn't made by Akari", t.Asked.Single());

        t.Picker.XmlPath = Fixture("2-unattended");
        page.Open();
        Assert.Equal("Unattended", page.Form.Fields().Get("WifiMode"));
        page.Reset();
        Assert.Equal("Interactive", page.Form.Fields().Get("WifiMode"));
    });

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
