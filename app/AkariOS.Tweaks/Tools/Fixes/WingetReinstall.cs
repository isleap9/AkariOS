using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Fixes;

/// <summary>src/Tweaks/Tools/Fixes/WingetReinstall.ps1 (winutil's Invoke-WPFFixesWinget): Install-AkariWingetTool -Force,
/// App Installer from winget-cli's latest release (<see cref="Core.Apps.Winget.EnsureTool"/> with force).</summary>
[TweakCode("tools-fix-winget")]
public sealed class WingetReinstall : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => TweakServices.Need(c.Services.Winget, "winget").EnsureTool(force: true);
}
