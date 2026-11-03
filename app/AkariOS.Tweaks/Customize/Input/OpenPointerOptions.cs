using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Input;

/// <summary>src/Tweaks/Customize/Input/OpenPointerOptions.ps1: opens the classic Mouse Properties on Pointer Options (an
/// Action: it changes nothing). It isn't waited for.</summary>
[TweakCode("input-open-pointer-options")]
public sealed class OpenPointerOptions : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => Panel.Open(c, "main.cpl ,2");
}

/// <summary>A Control Panel item through control.exe (Start-Process 'control.exe' / a .cpl file).</summary>
internal static class Panel
{
    public static void Open(TweakContext c, string arguments) =>
        FileData.Need(c.Services.Exe, "program runner").Run(Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "control.exe"), arguments, wait: false);
}
