using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/Autoruns.ps1: Sysinternals Autoruns: everything that starts with Windows (Open-AkariWingetTool: winget's Microsoft.Sysinternals.Autoruns installed first when
/// Autoruns64.exe is missing). An Action: it opens a tool.</summary>
[TweakCode("tools-autoruns")]
public sealed class Autoruns : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.OpenTool(c, "Microsoft.Sysinternals.Autoruns", "Autoruns64.exe");
}
