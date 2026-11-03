using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Start;

/// <summary>src/Tweaks/Customize/Start/NewStartMenu.ps1: its Registry rows, built with a foreach over the four feature
/// overrides.</summary>
[TweakCode("start-new-menu")]
public sealed class NewStartMenu : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) =>
        new[] { "2792562829", "3036241548", "734731404", "762256525" }
            .Select(f => FileData.Row($@"HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\14\{f}", "EnabledState", "DWord", 2)).ToList();
}
