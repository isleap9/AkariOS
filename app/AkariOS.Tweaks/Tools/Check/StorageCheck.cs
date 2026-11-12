using System.Globalization;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/StorageCheck.ps1: each lettered drive's free space in the console, then This PC. An
/// Action: a check, it changes nothing.</summary>
[TweakCode("tools-storage-check")]
public sealed class StorageCheck : ITweakCode
{
    private const double GB = 1024d * 1024 * 1024;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var v in TweakServices.Need(c.Services.Hardware, "hardware reader").Volumes())
            c.Log.Write(Line(v));
        ShellStart.Run(c, "explorer.exe", "shell:MyComputerFolder");
    }

    // '{0}: {1}% free ({2} of {3} GB)' with [math]::Round (to even, as Math.Round)
    public static string Line(VolumeInfo v) => string.Format(CultureInfo.InvariantCulture, "{0}: {1}% free ({2} of {3} GB)",
        v.Letter, Math.Round((double)v.Free / v.Size * 100), Math.Round(v.Free / GB), Math.Round(v.Size / GB));
}
