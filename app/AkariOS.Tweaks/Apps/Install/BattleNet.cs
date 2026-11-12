using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/BattleNet.ps1: after the winget install, Battle.net stops starting with Windows.</summary>
[TweakCode("install-battle-net")]
public sealed class BattleNet : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode) => AppSetup.RemoveStartup(c, "Battle.net");
}
