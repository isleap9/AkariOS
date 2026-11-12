using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Refresh;

/// <summary>src/Tweaks/Tools/Refresh/GamingRepair.ps1: Microsoft's gaming repair tool from AkariOS-Files, started. An
/// Action: a repair tool, run once.</summary>
[TweakCode("tools-gaming-repair")]
public sealed class GamingRepair : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var exe = PortableTool.Temp(c, "gamingrepairtool.exe");
        TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save("gamingrepairtool.exe", exe);
        ShellStart.Run(c, exe);
    }
}
