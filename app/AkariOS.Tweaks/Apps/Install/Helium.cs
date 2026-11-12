using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Helium.ps1: after the winget install, Akari's policies (no extension: Helium has
/// uBlock Origin built in) and its updaters gone.</summary>
[TweakCode("install-helium")]
public sealed class Helium : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        ChromiumPolicies.Set(c, @"HKLM:\SOFTWARE\Policies\Helium", uBlock: false);
        AppSetup.RemoveUpdaters(c, "Helium");
    }
}
