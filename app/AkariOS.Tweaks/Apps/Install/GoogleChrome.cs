using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/GoogleChrome.ps1: after the winget install, uBlock Origin Lite and Akari's
/// policies, and Google's updaters gone (Active Setup: Chrome's entry).</summary>
[TweakCode("install-google-chrome")]
public sealed class GoogleChrome : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        ChromiumPolicies.Set(c, @"HKLM:\SOFTWARE\Policies\Google\Chrome", uBlock: true);
        AppSetup.RemoveUpdaters(c, "Google", "Chrome");
    }
}
