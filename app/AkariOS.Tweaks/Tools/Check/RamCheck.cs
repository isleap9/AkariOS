using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/RamCheck.ps1: CPU-Z: the RAM's speed and channels (Open-AkariWingetTool: winget's CPUID.CPU-Z installed first when
/// cpuz.exe is missing). An Action: it opens a tool.</summary>
[TweakCode("tools-ram-check")]
public sealed class RamCheck : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.OpenTool(c, "CPUID.CPU-Z", "cpuz.exe");
}
