using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/Occt.ps1: OCCT, a CPU, RAM and storage stress test (Open-AkariWingetTool: winget's OCBase.OCCT.Personal installed first when
/// OCCT*.exe is missing). An Action: it opens a tool.</summary>
[TweakCode("tools-occt")]
public sealed class Occt : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.OpenTool(c, "OCBase.OCCT.Personal", "OCCT*.exe");
}
