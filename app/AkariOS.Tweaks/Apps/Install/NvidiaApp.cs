using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/NvidiaApp.ps1: NVIDIA's installer from AkariOS-Files, run silently. No Detect.</summary>
[TweakCode("install-nvidia-app")]
public sealed class NvidiaApp : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => Download.Install(c, "nvidiaapp.exe", Download.Windows(c, @"Temp\nvidiaapp.exe"), "/s");
}
