using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Occt.ps1: after the winget install, a Start menu shortcut (a portable package has
/// none of its own).</summary>
[TweakCode("install-occt")]
public sealed class Occt : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        if (AppSetup.WingetExe(c, "OCBase.OCCT.Personal", "OCCT*.exe") is { } exe) AppSetup.Shortcut(c, "OCCT", exe);
    }
}
