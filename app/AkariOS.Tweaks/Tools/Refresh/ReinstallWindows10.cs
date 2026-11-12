using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Refresh;

/// <summary>src/Tweaks/Tools/Refresh/ReinstallWindows10.ps1: Microsoft's Media Creation Tool for Windows 10, from
/// Microsoft's link, started. An Action: Microsoft's tool asks before it changes anything.</summary>
[TweakCode("tools-reinstall-windows-10")]
public sealed class ReinstallWindows10 : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        PortableTool.DownloadAndStart(c, "https://go.microsoft.com/fwlink/?LinkId=691209", PortableTool.Temp(c, "MediaCreationTool_Win10.exe"));
}
