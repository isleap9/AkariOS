using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/GogGalaxy.ps1: after the winget install, GOG GALAXY stops starting with Windows.</summary>
[TweakCode("install-gog-launcher")]
public sealed class GogGalaxy : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode) => AppSetup.RemoveStartup(c, "GalaxyClient", "GogGalaxy");
}
