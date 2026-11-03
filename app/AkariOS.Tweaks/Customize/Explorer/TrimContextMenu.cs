using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Explorer;

/// <summary>src/Tweaks/Customize/Explorer/TrimContextMenu.ps1: its Registry rows, which the file builds with a foreach
/// and two helper blocks ($w11: a Windows 11 only Default; $handler: a shell extension's key and its CLSID). $c and
/// $verb are read from the file. Each removed entry holds Windows' own values, so Revert rebuilds it.</summary>
[TweakCode("explorer-trim-context-menu")]
public sealed class TrimContextMenu : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c)
    {
        var classes = (string)FileData.Variable(tweak, c, "c")!;
        var verb = (string)FileData.Variable(tweak, c, "verb")!;
        static OsValue W11(object? v) => new(null, v);
        var pin = $@"{classes}\Folder\shell\pintohome";
        var fav = $@"{classes}\*\shell\pintohomefile";
        var rows = new List<RegistryRow>
        {
            FileData.Row(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoCustomizeThisFolder", "DWord", 1),
            FileData.Row(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer", "NoPreviousVersionsPage", "DWord", 1),
        };
        // Open in Terminal, Scan with Microsoft Defender, Give access to
        foreach (var g in new[] { "{9F156763-7844-4DC4-B2B1-901F640F5155}", "{09A47860-11B0-4DA5-AFA5-26D86198A780}", "{f81e9010-6ea4-11ce-a7ff-00aa003ca9f6}" })
            rows.Add(FileData.Row(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked", g, "String", ""));
        // Pin to Quick access
        rows.Add(FileData.RemovedRow($@"{pin}\command", "DelegateExecute", "String", OsValue.Both(verb)));
        rows.Add(FileData.RemovedRow(pin, "AppliesTo", "String", OsValue.Both(
            "System.ParsingName:<>\"::{f874310e-b6b7-47dc-bc84-b9e6b38f5903}\" AND System.ParsingName:<>\"::{679f85cb-0220-4080-b29b-5540cc05aab6}\" AND System.IsFolder:=System.StructuredQueryType.Boolean#True")));
        rows.Add(FileData.RemovedRow(pin, "CommandStateHandler", "String", OsValue.Both(verb)));
        rows.Add(FileData.RemovedRow(pin, "CommandStateSync", "String", OsValue.Both("")));
        rows.Add(FileData.RemovedRow(pin, "MUIVerb", "String", OsValue.Both("@shell32.dll,-51601")));
        rows.Add(FileData.RemovedRow(pin, "SkipCloudDownload", "DWord", OsValue.Both(0)));
        rows.Add(FileData.RemovedKeyRow(pin, OsValue.Both("Key")));
        // Add to Favorites (Windows 11)
        rows.Add(FileData.RemovedRow($@"{fav}\command", "DelegateExecute", "String", W11(verb)));
        rows.Add(FileData.RemovedRow(fav, "CommandStateHandler", "String", W11(verb)));
        rows.Add(FileData.RemovedRow(fav, "CommandStateSync", "String", W11("")));
        rows.Add(FileData.RemovedRow(fav, "MUIVerb", "String", W11("@shell32.dll,-51608")));
        rows.Add(FileData.RemovedRow(fav, "NeverDefault", "String", W11("")));
        rows.Add(FileData.RemovedRow(fav, "SkipCloudDownload", "DWord", W11(0)));
        rows.Add(FileData.RemovedKeyRow(fav, W11("Key")));
        // Troubleshoot compatibility, Include in library, Share, Send to
        void Handler(string path, string clsid)
        {
            rows.Add(FileData.RemovedRow(path, "(default)", "String", OsValue.Both(clsid)));
            rows.Add(FileData.RemovedKeyRow(path, OsValue.Both("Key")));
        }
        Handler($@"{classes}\exefile\shellex\ContextMenuHandlers\Compatibility", "{1d27f844-3a1f-4410-85ac-14651078412d}");
        Handler($@"{classes}\Folder\ShellEx\ContextMenuHandlers\Library Location", "{3dad6c5d-2167-4cae-9914-f99e41c12cfa}");
        Handler($@"{classes}\AllFilesystemObjects\shellex\ContextMenuHandlers\ModernSharing", "{e2bf9676-5f8f-435c-97eb-11607a5bedf7}");
        Handler($@"{classes}\AllFilesystemObjects\shellex\ContextMenuHandlers\SendTo", "{7BA4C740-9E81-11CF-99D3-00AA004AE837}");
        Handler($@"{classes}\UserLibraryFolder\shellex\ContextMenuHandlers\SendTo", "{7BA4C740-9E81-11CF-99D3-00AA004AE837}");
        return rows;
    }
}
