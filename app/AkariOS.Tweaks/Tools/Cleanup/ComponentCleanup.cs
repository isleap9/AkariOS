using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/ComponentCleanup.ps1 (winutil W3): dism.exe's component cleanup with ResetBase;
/// 0 and 3010 (a restart due) are fine, anything else fails with the code. An Action.</summary>
[TweakCode("tools-component-cleanup")]
public sealed class ComponentCleanup : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var code = FileData.Need(c.Services.Dism, "DISM").Exe("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase");
        if (code is not 0 and not 3010) throw new InvalidOperationException($"DISM's component cleanup failed (0x{code:X8}).");
    }
}
