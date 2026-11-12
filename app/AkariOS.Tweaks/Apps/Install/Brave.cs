using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Brave.ps1: after the winget install, uBlock Origin Lite and Akari's policies, and
/// Brave's updaters gone.</summary>
[TweakCode("install-brave")]
public sealed class Brave : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        ChromiumPolicies.Set(c, @"HKLM:\SOFTWARE\Policies\BraveSoftware\Brave", uBlock: true);
        AppSetup.RemoveUpdaters(c, "Brave");
    }
}
