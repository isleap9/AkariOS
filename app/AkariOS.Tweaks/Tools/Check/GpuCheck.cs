using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/GpuCheck.ps1: GPU-Z: PCIe link, Resizable BAR, driver, clocks (Open-AkariWingetTool: winget's TechPowerUp.GPU-Z installed first when
/// GPU-Z.exe is missing). An Action: it opens a tool.</summary>
[TweakCode("tools-gpu-check")]
public sealed class GpuCheck : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.OpenTool(c, "TechPowerUp.GPU-Z", "GPU-Z.exe");
}
