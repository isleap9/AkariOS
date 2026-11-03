using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Gaming;

/// <summary>src/Tweaks/Optimize/Gaming/XboxController.ps1: its Registry rows, which the file builds with a foreach over
/// the two Game Bar links ($c is read from the file).</summary>
[TweakCode("gaming-xbox-controller-no-game-bar")]
public sealed class XboxController : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c)
    {
        var classes = (string)FileData.Variable(tweak, c, "c")!;
        var rows = new List<RegistryRow>
        {
            FileData.Row(@"HKCU:\Software\Microsoft\GameBar", "UseNexusForGameBarEnabled", "DWord", 0),
            FileData.Row(@"HKCU:\Software\Microsoft\GameBar", "GamepadNexusChordEnabled", "DWord", 0),
        };
        foreach (var p in new[] { "ms-gamebar", "ms-gamingoverlay" })
        {
            rows.Add(FileData.Row($@"{classes}\{p}", "NoOpenWith", "String", ""));
            rows.Add(FileData.Row($@"{classes}\{p}\shell\open\command", "(default)", "String", @"%SystemRoot%\System32\systray.exe"));
            rows.Add(FileData.KeyRow($@"{classes}\{p}\shell\open\command"));
        }
        // ms-gamebarservices is not a Windows link: Revert deletes it
        var services = $@"{classes}\ms-gamebarservices";
        rows.Add(FileData.Row(services, "(default)", "String", "URL:ms-gamebarservices"));
        rows.Add(FileData.Row(services, "URL Protocol", "String", ""));
        rows.Add(FileData.Row(services, "NoOpenWith", "String", ""));
        rows.Add(FileData.Row($@"{services}\shell\open\command", "(default)", "String", @"%SystemRoot%\System32\systray.exe"));
        rows.Add(FileData.KeyRow(services));
        return rows;
    }
}
