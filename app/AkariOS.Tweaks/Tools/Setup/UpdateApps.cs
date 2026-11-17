using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Setup;

/// <summary>src/Tweaks/Tools/Setup/UpdateApps.ps1 (after Chris Titus Tech's winutil, MIT: Invoke-WPFInstallUpgrade):
/// Update-AkariWingetPackages, one "winget upgrade --all" (<see cref="Core.Apps.Winget.UpgradeAll"/>). Also the
/// Downloads page's "Update all apps" button. An Action: an update has no Default to go back to.</summary>
[TweakCode("tools-update-apps")]
public sealed class UpdateApps : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => TweakServices.Need(c.Services.Winget, "winget").UpgradeAll();
}
