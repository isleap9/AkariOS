using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/EpicGames.ps1: after the winget install, the Epic Games Launcher stops starting with Windows.</summary>
[TweakCode("install-epic-games")]
public sealed class EpicGames : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode) => AppSetup.RemoveStartup(c, "EpicGamesLauncher");
}
