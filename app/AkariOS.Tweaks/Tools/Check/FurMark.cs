using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/FurMark.ps1: FurMark 2, a GPU stress test (Open-AkariWingetTool: winget's Geeks3D.FurMark.2 installed first when
/// FurMark_GUI.exe is missing). An Action: it opens a tool.</summary>
[TweakCode("tools-furmark")]
public sealed class FurMark : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.OpenTool(c, "Geeks3D.FurMark.2", "FurMark_GUI.exe");
}
