using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/UpdateHealthTools.ps1: the MSI, the uhssvc service key and the PLUGScheduler task.
/// An Action: Windows Update brings them back.</summary>
[TweakCode("remove-update-health-tools")]
public sealed class UpdateHealthTools : ITweakCode
{
    private const string Like = "*Microsoft Update Health Tools*";
    private const string Service = @"HKLM:\SYSTEM\ControlSet001\Services\uhssvc";

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        Msi.Done(c, Like) == TweakState.Optimized && !c.Registry.KeyExists(Service) ? TweakState.Optimized : TweakState.Default;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        AppSetup.UninstallMsi(c, Like);
        // -ErrorAction SilentlyContinue
        try { c.Registry.DeleteKey(Service); } catch (Exception e) when (e is UnauthorizedAccessException or IOException or System.Security.SecurityException) { }
        Tasks.Unregister(c, n => string.Equals(n, "PLUGScheduler", StringComparison.OrdinalIgnoreCase));
    }
}
