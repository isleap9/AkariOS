using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.OneClick.Drivers;

/// <summary>src/Tweaks/OneClick/Drivers/DduClean.ps1: in Safe Mode, DDU removes the GPU and the Realtek / Sound Blaster
/// audio drivers and restarts the PC (Restarts). Not prepared (its download failed): the drivers stay, said in the log,
/// and the Run goes on after Akari's own restart. An Action: removed drivers can't be put back.</summary>
[TweakCode("oneclick-ddu-clean")]
public sealed class DduClean : ITweakCode
{
    public const string Arguments = "-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart";

    public static string Program(TweakContext c) =>
        Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "Temp", "ddu", "Display Driver Uninstaller.exe");

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var exe = Program(c);
        if (!File.Exists(exe)) { c.Log.Write("DDU is not ready (oneclick-ddu-prepare): the drivers stay"); return; }
        // its own window, waited for (Start-Process -Wait)
        TweakServices.Need(c.Services.Exe, "program runner").Run(exe, Arguments, wait: true, capture: false);
    }
}
