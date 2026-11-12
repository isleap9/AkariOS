using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Apps.Remove;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/WebView2Runtime.ps1: before the winget install, the WebView2 removal's block on
/// Edge Update installing it lifted.</summary>
[TweakCode("install-webview2-runtime")]
public sealed class WebView2Runtime : ITweakCode
{
    public void Before(Tweak tweak, TweakContext c) =>
        c.Registry.RemoveValue(EdgeUpdate.Policies, "Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}");
}
