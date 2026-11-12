using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/7Zip.ps1: after the winget install, a flat context menu with the common commands
/// only.</summary>
[TweakCode("install-7-zip")]
public sealed class SevenZip : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        c.Registry.SetValue(@"HKCU:\Software\7-Zip\Options", "ContextMenu", 259, "DWord");
        c.Registry.SetValue(@"HKCU:\Software\7-Zip\Options", "CascadedMenu", 0, "DWord");
    }
}
