using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/SnippingToolLegacy.ps1: Windows 10's Snipping Tool installer from AkariOS-Files;
/// done when SnippingTool.exe is back.</summary>
[TweakCode("install-snipping-tool-legacy")]
public sealed class SnippingToolLegacy : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => Download.Done(Download.Windows(c, @"System32\SnippingTool.exe"));

    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        Download.Install(c, "snippingtool.exe", Download.Windows(c, @"Temp\snippingtool.exe"));
}
