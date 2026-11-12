using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/OnboardMemoryManager.ps1: Logitech's Onboard Memory Manager from AkariOS-Files,
/// with a Start menu shortcut.</summary>
[TweakCode("install-onboard-memory-manager")]
public sealed class OnboardMemoryManager : ITweakCode
{
    private static string Exe(TweakContext c) => Download.X86(c, @"Onboard Memory Manager\Onboard Memory Manager.exe");

    public TweakState Detect(Tweak tweak, TweakContext c) => Download.Done(Exe(c));

    public void Apply(Tweak tweak, TweakContext c, object? value) => Download.Tool(c, "Onboard Memory Manager", "omm.exe", Exe(c));
}
