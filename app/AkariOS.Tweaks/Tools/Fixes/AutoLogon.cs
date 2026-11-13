using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Fixes;

/// <summary>src/Tweaks/Tools/Fixes/AutoLogon.ps1 (winutil's Invoke-WPFPanelAutologin): Sysinternals Autologon
/// (Open-AkariWingetTool: winget's Microsoft.Sysinternals.Autologon installed first when Autologon64.exe is missing).
/// An Action: the tool makes the change.</summary>
[TweakCode("tools-autologon")]
public sealed class AutoLogon : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.OpenTool(c, "Microsoft.Sysinternals.Autologon", "Autologon64.exe");
}
