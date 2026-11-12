using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/GameInput.ps1: the Microsoft GameInput MSI. An Action: the games or Windows updates
/// that need it install it again.</summary>
[TweakCode("remove-gameinput")]
public sealed class GameInput : ITweakCode
{
    private const string Like = "*Microsoft GameInput*";
    public TweakState Detect(Tweak tweak, TweakContext c) => Msi.Done(c, Like);
    public void Apply(Tweak tweak, TweakContext c, object? value) => AppSetup.UninstallMsi(c, Like);
}
