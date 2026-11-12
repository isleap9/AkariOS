using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/UpdateForX64.ps1: Windows 10's installer update MSI. An Action: Windows Update
/// brings it back.</summary>
[TweakCode("remove-update-for-x64")]
public sealed class UpdateForX64 : ITweakCode
{
    private const string Like = "*Update for x64-based Windows Systems*";
    public TweakState Detect(Tweak tweak, TweakContext c) => Msi.Done(c, Like);
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.UninstallMsi(c, Like);
}
