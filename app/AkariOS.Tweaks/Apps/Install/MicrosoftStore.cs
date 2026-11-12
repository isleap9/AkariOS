using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/MicrosoftStore.ps1: the Store back after a debloat (Install-AkariMicrosoftStore =
/// the engine's <see cref="Core.Apps.Winget.EnsureStore"/>): registered again, else winget msstore, else wsreset -i.</summary>
[TweakCode("install-microsoft-store")]
public sealed class MicrosoftStore : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) =>
        TweakServices.Need(c.Services.Apps, "app manager").IsInstalled(Core.Apps.Winget.StorePackage) ? TweakState.Optimized : TweakState.Default;

    public void Apply(Tweak tweak, TweakContext c, object? value) => TweakServices.Need(c.Services.Winget, "winget").EnsureStore();
}
