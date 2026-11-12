using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native Apps lists against src\UI\Apps.ps1 (Oracle/Export-AppLists.ps1) on the real Tweaks and Groups, for two
/// made-up PCs: the same Store apps (known, found on the PC, Keep), Optional and Windows features, installs, Install
/// cards (the restore card only with what is missing), sources and icon files, in the same order.
/// </summary>
public class AppListsOracleTests
{
    // known apps (one Keep, one with a bundled .png, one with a .mono.png), two the data file doesn't list
    private static readonly string[] Installed = ["Clipchamp.Clipchamp", "Microsoft.Paint", "Microsoft.BingNews", "Microsoft.WindowsAlarms",
        "Contoso.Unknown", "Fabrikam.Thing"];
    private static readonly string[] Capabilities = ["App.StepsRecorder~~~~0.0.1.0", "Browser.InternetExplorer~~~~0.0.11.0", "Microsoft.Windows.Notepad~~~~0.0.1.0",
        "Some.Other.Capability~~~~0.0.1.0"];
    private static readonly string[] Features = ["Printing-XPSServices-Features", "Printing-PrintToPDFServices-Features", "NetFx3", "Zz-Other-Feature"];
    // every package on the PC: the Store is there, the Snipping Tool app isn't
    private static readonly string[] Appx = ["Microsoft.WindowsStore", "Microsoft.Paint", "Clipchamp.Clipchamp"];
    private static readonly Dictionary<string, string> Logos = new() { ["Clipchamp.Clipchamp"] = @"C:\Apps\Clipchamp\logo.png" };

    private static string Assets => Path.Combine(Repo.Src, @"Assets\Apps");

    private static readonly Lazy<JsonElement> PowerShell = new(() => Oracle.Run("Export-AppLists.ps1",
    [
        "-Src", Repo.Src, "-Installed", string.Join(";", Installed), "-Capabilities", string.Join(";", Capabilities),
        "-Features", string.Join(";", Features), "-Appx", string.Join(";", Appx), "-Logos", string.Join(";", Logos.Select(l => $"{l.Key}={l.Value}")),
    ]));

    private static readonly Lazy<LoadResult> Loaded = new(() =>
        new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load());

    public static TheoryData<string> Pcs => ["Win11", "Win10"];

    private static FakeSystem Pc(string name) => name == "Win11"
        ? new FakeSystem { Gpus = [new Gpu("x", "GeForce", "NVIDIA")] }
        : new FakeSystem { Build = 19045, Edition = "Core", Chassis = Chassis.Laptop };

    private static string Row(AppItem i)
    {
        var t = i.Tweak;
        var icon = (AppLists.IconFile(t, Logos, Assets, File.Exists) ?? "").Replace(Assets, "%Assets%", StringComparison.Ordinal);
        return $"{t.Id} | {t.Name} | {t.Package} | {i.Installed} | {t.Keep} | {t.Risk} | {t.Description} | {AppLists.Source(t)} | {icon}";
    }

    private static List<string> PsRows(string pc, string list) => PowerShell.Value.GetProperty(pc).GetProperty(list).EnumerateArray().Select(r =>
        string.Join(" | ", new[] { "Id", "Name", "Package", "Installed", "Keep", "Risk", "Description", "Source", "Icon" }.Select(k => Text(r.GetProperty(k))))).ToList();

    private static string? Text(JsonElement v) => v.ValueKind switch
    {
        JsonValueKind.True => "True",
        JsonValueKind.False => "False",
        JsonValueKind.Null => "",
        _ => v.GetString(),
    };

    [Theory, MemberData(nameof(Pcs))]
    public void The_same_store_apps(string pc) =>
        Assert.Equal(PsRows(pc, "Store"), AppLists.Store(Loaded.Value.Tweaks, Loaded.Value.Groups, Installed).Select(Row));

    [Theory, MemberData(nameof(Pcs))]
    public void The_same_optional_and_windows_features(string pc)
    {
        Assert.Equal(PsRows(pc, "Capabilities"), AppLists.Found(Loaded.Value.Groups, EntryKind.CapabilityRemove, Capabilities).Select(Row));
        Assert.Equal(PsRows(pc, "Features"), AppLists.Found(Loaded.Value.Groups, EntryKind.FeatureDisable, Features).Select(Row));
    }

    // two installs share a name (Windows Terminal: the winget one and the Store restore): 5.1's Sort-Object isn't
    // stable, so the names come in the same order and the rows are the same, ties in either order
    [Theory, MemberData(nameof(Pcs))]
    public void The_same_installs(string pc)
    {
        var ps = PsRows(pc, "Install");
        var mine = AppLists.Install(Loaded.Value.Tweaks, Pc(pc)).Select(Row).ToList();
        Assert.Equal(ps.Select(r => r.Split(" | ")[1]), mine.Select(r => r.Split(" | ")[1]));
        Assert.Equal(ps.Order(StringComparer.Ordinal), mine.Order(StringComparer.Ordinal));
    }

    [Theory, MemberData(nameof(Pcs))]
    public void The_same_install_cards(string pc)
    {
        var ps = PowerShell.Value.GetProperty(pc).GetProperty("Cards").EnumerateArray()
            .Select(c => $"{c.GetProperty("Title").GetString()}: {string.Join(", ", c.GetProperty("Ids").EnumerateArray().Select(i => i.GetString()))}");
        Assert.Equal(ps, AppLists.InstallCards(Loaded.Value.Tweaks, Pc(pc), Appx).Select(c => $"{c.Title}: {string.Join(", ", c.Items.Select(i => i.Tweak.Id))}"));
    }
}
