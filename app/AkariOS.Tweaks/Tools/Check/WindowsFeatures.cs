using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/WindowsFeatures.ps1: "Turn Windows features on or off" (optionalfeatures.exe). An
/// Action: it opens a window.</summary>
[TweakCode("tools-windows-features")]
public sealed class WindowsFeatures : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "optionalfeatures.exe");
}
