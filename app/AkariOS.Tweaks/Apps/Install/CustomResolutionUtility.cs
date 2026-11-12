using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/CustomResolutionUtility.ps1: CRU and Scaled Resolution Editor from AkariOS-Files,
/// with Start menu shortcuts.</summary>
[TweakCode("install-custom-resolution-utility")]
public sealed class CustomResolutionUtility : ITweakCode
{
    private static string Cru(TweakContext c) => Download.X86(c, @"CRUSRE\CRU.exe");
    private static string Sre(TweakContext c) => Download.X86(c, @"CRUSRE\SRE.exe");

    public TweakState Detect(Tweak tweak, TweakContext c) => Download.Done(Cru(c), Sre(c));

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        Download.Tool(c, "Custom Resolution Utility", "cru.exe", Cru(c));
        Download.Tool(c, "Scaled Resolution Editor", "sre.exe", Sre(c));
    }
}
