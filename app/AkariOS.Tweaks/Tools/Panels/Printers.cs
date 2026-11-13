using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/Printers.ps1: the Printers shell folder in Explorer (an Action: it opens a window).</summary>
[TweakCode("tools-panel-printers")]
public sealed class Printers : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "explorer.exe", "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}");
}
