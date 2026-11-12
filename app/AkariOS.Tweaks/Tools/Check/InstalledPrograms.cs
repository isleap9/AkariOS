using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/InstalledPrograms.ps1: Programs and Features (appwiz.cpl). An Action: it opens a window.</summary>
[TweakCode("tools-installed-programs")]
public sealed class InstalledPrograms : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "appwiz.cpl");
}
