using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Refresh;

/// <summary>src/Tweaks/Tools/Refresh/ReinstallWindows11.ps1: Microsoft's Media Creation Tool for Windows 11, from
/// Microsoft's link, started. An Action: Microsoft's tool asks before it changes anything.</summary>
[TweakCode("tools-reinstall-windows-11")]
public sealed class ReinstallWindows11 : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        PortableTool.DownloadAndStart(c, "https://go.microsoft.com/fwlink/?linkid=2156295", PortableTool.Temp(c, "MediaCreationTool_Win11.exe"));
}
