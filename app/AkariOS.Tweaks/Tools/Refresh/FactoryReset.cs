using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Refresh;

/// <summary>src/Tweaks/Tools/Refresh/FactoryReset.ps1: Settings › Recovery ("Reset this PC"). An Action: Windows asks
/// before it resets anything.</summary>
[TweakCode("tools-factory-reset")]
public sealed class FactoryReset : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "ms-settings:recovery");
}
