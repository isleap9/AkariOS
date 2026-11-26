using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// Startup apps (X2): the pure parts against src\Core\Startup.ps1 and src\UI\StartupPage.ps1 (Oracle/Export-Startup.ps1),
/// then the entries read, switched and removed on a test key and a temp folder.
/// </summary>
public sealed class StartupTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-startup-{Guid.NewGuid():N}");

    public StartupTests() => Directory.CreateDirectory(_dir);

    public void Dispose()
    {
        _key.Dispose();
        Directory.Delete(_dir, true);
    }

    private static readonly (bool Enabled, long FileTime)[] Approved =
        [(true, 0), (false, new DateTime(2026, 11, 26, 10, 0, 0, DateTimeKind.Utc).ToFileTimeUtc()), (false, 133_000_000_000_000_000)];

    private static readonly int[]?[] Bytes = [null, [], [2, 0, 0, 0], [6], [3, 0, 0, 0], [7, 1], [255]];

    private static readonly string[] Commands =
    [
        "\"C:\\Program Files\\Steam\\steam.exe\" -silent", "C:\\Program Files\\App\\app.EXE /background", "rundll32 shell32.dll,Control",
        "\"C:\\unclosed", "   ", "", "plain", "%windir%\\system32\\SecurityHealthSystray.exe", "C:\\a.exe.bak\\b.exe",
    ];

    private static readonly StartupItem[] Items =
    [
        Item("Steam", true, "User", "steam.exe", "Valve"),
        Item("discord", false, "User", "x.exe", ""),
        Item("SecurityHealth", true, "Machine", "SecurityHealthSystray.exe", "Microsoft Corporation"),
        Item("Discord", true, "Machine", "x.exe", "", "A"),
        Item("Échelle", false, "Machine", "e.exe", "", "Startup folder, all users"),
        Item("zeta-tool", true, "User", "z.exe", ""),
    ];

    private static StartupItem Item(string name, bool on, string scope, string command, string publisher, string location = "L") =>
        new(StartupItems.KeyOf(location, name), name, command, location, scope, "Registry", "", "", "", on, publisher);

    private static readonly (string Filter, string Query)[] Views =
        [("All", ""), ("On", ""), ("Off", ""), ("User", ""), ("Machine", ""), ("All", "valve"), ("All", "zzz"), ("Off", "ÉCH"), ("All", " x.exe ")];

    private static readonly Lazy<JsonElement> PowerShell = new(() =>
    {
        var cases = Path.Combine(Path.GetTempPath(), $"akari-startup-cases-{Guid.NewGuid():N}.json");
        File.WriteAllText(cases, JsonSerializer.Serialize(new
        {
            Approved = Approved.Select(a => new { a.Enabled, a.FileTime }),
            Bytes = Bytes.Select(b => new { Value = b }),
            Commands,
            Items = Items.Select(i => new { i.Name, i.Command, i.Location, i.Scope, i.Enabled, i.Publisher }),
            Views = Views.Select(v => new { v.Filter, v.Query }),
        }));
        try { return Oracle.Run("Export-Startup.ps1", "-Src", Repo.Src, "-Cases", cases); }
        finally { File.Delete(cases); }
    });

    private static List<string> Strings(JsonElement e) => e.EnumerateArray().Select(x => x.ToString()).ToList();

    [Fact]
    public void Approved_values_are_powershells()
    {
        Assert.Equal(Strings(PowerShell.Value.GetProperty("Approved")),
            Approved.Select(a => string.Join(",", StartupItems.Approved(a.Enabled, DateTime.FromFileTimeUtc(a.FileTime)))).ToList());
        Assert.Equal(PowerShell.Value.GetProperty("Enabled").EnumerateArray().Select(x => x.GetBoolean()).ToList(),
            Bytes.Select(b => StartupItems.IsEnabled(b?.Select(x => (byte)x).ToArray())).ToList());
    }

    [Fact]
    public void Programs_are_powershells() =>
        Assert.Equal(Strings(PowerShell.Value.GetProperty("Program")), Commands.Select(StartupItems.Program).ToList());

    [Fact]
    public void Views_and_counts_are_powershells()
    {
        var ps = PowerShell.Value.GetProperty("Views").EnumerateArray().ToList();
        Assert.Equal(Views.Length, ps.Count);
        for (var i = 0; i < Views.Length; i++)
        {
            var view = StartupLists.View(Items, Views[i].Filter, Views[i].Query);
            Assert.Equal(ps[i].GetProperty("Keys").GetString(), string.Join(",", view.Select(x => x.Key)));
            Assert.Equal(ps[i].GetProperty("Count").GetString(), StartupLists.CountText(Items, view));
        }
    }

    private (RegistryEngine Reg, StartupItems Items, string Folder) Make()
    {
        var reg = new RegistryEngine(new RedirectedRegistryPaths(_key.Root));
        var folder = Path.Combine(_dir, "Startup");
        Directory.CreateDirectory(folder);
        StartupLocation[] where =
        [
            new("Registry, this user", "User", "Registry", @"HKCU:\Run", @"HKCU:\Approved\Run"),
            new("Registry, missing", "Machine", "Registry", @"HKLM:\Missing", @"HKLM:\Approved\Missing"),
            new("Startup folder, this user", "User", "Folder", folder, @"HKCU:\Approved\StartupFolder"),
        ];
        reg.SetValue(@"HKCU:\Run", "Tool", "\"C:\\NoSuch\\tool.exe\" -min", "String");
        reg.SetValue(@"HKCU:\Approved\Run", "Tool", new byte[] { 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, "Binary");
        File.WriteAllText(Path.Combine(folder, "Chat.lnk"), "x");
        File.WriteAllText(Path.Combine(folder, "desktop.ini"), "x");
        return (reg, new StartupItems(reg, where, p => p.EndsWith("tool.exe") ? "Tool Co" : ""), folder);
    }

    [Fact]
    public void Reads_run_values_and_folder_files_with_their_state()
    {
        var (_, items, folder) = Make();
        var all = items.All();
        Assert.Equal(["Registry, this user|Tool=False:User:Registry:Tool Co", "Startup folder, this user|Chat.lnk=True:User:Folder:"],
            all.Select(i => $"{i.Key}={i.Enabled}:{i.Scope}:{i.Kind}:{i.Publisher}"));
        Assert.Equal("\"C:\\NoSuch\\tool.exe\" -min", all[0].Command);
        Assert.Equal(Path.Combine(folder, "Chat.lnk"), all[1].File);
    }

    [Fact]
    public void Switches_through_startup_approved_and_leaves_the_entry()
    {
        var (reg, items, _) = Make();
        var when = new DateTime(2026, 11, 26, 10, 0, 0, DateTimeKind.Utc);
        items.SetEnabled(items.All()[0], true, when);
        Assert.Equal(new byte[] { 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, reg.GetValue(@"HKCU:\Approved\Run", "Tool"));
        items.SetEnabled(items.All()[1], false, when);
        Assert.False(items.All()[1].Enabled);
        Assert.Equal(StartupItems.Approved(false, when), reg.GetValue(@"HKCU:\Approved\StartupFolder", "Chat.lnk"));
        Assert.Equal("\"C:\\NoSuch\\tool.exe\" -min", reg.GetValue(@"HKCU:\Run", "Tool"));
    }

    [Fact]
    public void Remove_deletes_the_value_or_file_and_its_approved_value()
    {
        var (reg, items, folder) = Make();
        foreach (var i in items.All()) items.Remove(i);
        Assert.Null(reg.GetValue(@"HKCU:\Run", "Tool"));
        Assert.Null(reg.GetValue(@"HKCU:\Approved\Run", "Tool"));
        Assert.False(File.Exists(Path.Combine(folder, "Chat.lnk")));
        Assert.Empty(items.All());
    }

    [Fact]
    public void Locations_are_the_real_users_and_the_machines()
    {
        var reg = new RegistryEngine(new RedirectedRegistryPaths(_key.Root));
        var none = StartupItems.Locations(reg, new TweakServices());
        Assert.Equal(["Registry, this user", "Registry, all users", "Registry, all users (32-bit)"], none.Select(l => l.Location));
        reg.SetValue(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", "Startup", @"D:\Me\Startup", "String");
        var all = StartupItems.Locations(reg, new TweakServices { ProgramData = @"D:\PD" });
        Assert.Equal(@"D:\Me\Startup", all[3].Path);
        Assert.Equal(@"D:\PD\Microsoft\Windows\Start Menu\Programs\StartUp", all[4].Path);
        Assert.Equal(@"HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32", all[2].Approved);
    }
}
