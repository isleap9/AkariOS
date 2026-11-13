using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/OoShutUp10.ps1 (winutil W3): O&amp;O ShutUp10++ (Open-AkariWingetTool: winget's
/// OO-Software.ShutUp10 installed first when OOSU10.exe is missing). An Action: it opens a tool.</summary>
[TweakCode("tools-oosu10")]
public sealed class OoShutUp10 : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.OpenTool(c, "OO-Software.ShutUp10", "OOSU10.exe");
}
