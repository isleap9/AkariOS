using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/NvidiaProfileInspector.ps1: Akari's single-exe build from AkariOS-Files, with a
/// Start menu shortcut.</summary>
[TweakCode("install-nvidia-profile-inspector")]
public sealed class NvidiaProfileInspector : ITweakCode
{
    private static string Exe(TweakContext c) => Download.X86(c, @"Nvidia Profile Inspector\Nvidia Profile Inspector.exe");

    public TweakState Detect(Tweak tweak, TweakContext c) => Download.Done(Exe(c));

    public void Apply(Tweak tweak, TweakContext c, object? value) => Download.Tool(c, "Nvidia Profile Inspector", "inspector.exe", Exe(c));
}
