using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Rufus.ps1: after the winget install, a Start menu shortcut (a portable package has
/// none of its own).</summary>
[TweakCode("install-rufus")]
public sealed class Rufus : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        if (AppSetup.WingetExe(c, "Rufus.Rufus", "rufus*.exe") is { } exe) AppSetup.Shortcut(c, "Rufus", exe);
    }
}
