using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/SnippingToolLegacy.ps1: Windows 10's Snipping Tool uninstalls itself. An Action:
/// its installer brings it back.</summary>
[TweakCode("remove-snipping-tool-legacy")]
public sealed class SnippingToolLegacy : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => SelfUninstalling.Done(c, "SnippingTool.exe");
    public void Apply(Tweak tweak, TweakContext c, object? value) => SelfUninstalling.Run(c, "SnippingTool.exe", "SnippingTool");
}
