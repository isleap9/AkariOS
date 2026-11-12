using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/ElectronicArts.ps1: after the winget install, the EA app stops starting with Windows.</summary>
[TweakCode("install-electronic-arts")]
public sealed class ElectronicArts : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode) => AppSetup.RemoveStartup(c, "EADM");
}
