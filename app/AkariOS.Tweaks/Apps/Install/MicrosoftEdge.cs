using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Apps.Remove;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/MicrosoftEdge.ps1: before the winget install, the Edge removal's block on Edge
/// Update installing Edge lifted.</summary>
[TweakCode("install-microsoft-edge")]
public sealed class MicrosoftEdge : ITweakCode
{
    public void Before(Tweak tweak, TweakContext c)
    {
        c.Registry.RemoveValue(EdgeUpdate.Policies, "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}");
        c.Registry.RemoveValue(EdgeUpdate.Policies, "DoNotUpdateToEdgeWithChromium");
    }
}
