using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Steam.ps1: after the winget install, Steam stops starting with Windows.</summary>
[TweakCode("install-steam")]
public sealed class Steam : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode) => AppSetup.RemoveStartup(c, "Steam");
}
