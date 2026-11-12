using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Security;

/// <summary>src/Tweaks/Advanced/Security/DefenderSettings.ps1: the Windows Security values of Files/defender-settings.psd1,
/// written in Safe Mode as TrustedInstaller and then as admin (the HKCU rows the real user's). Apply also clears memory
/// integrity's boot-cycle mark and virtualization-based security (its registry value and three bcdedit settings, which
/// have no Revert: Windows turns them back on with memory integrity).</summary>
[TweakCode("security-defender-settings")]
public sealed class DefenderSettings : ITweakCode
{
    private const string Hvci = @"HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity";

    public static IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => DefenderRows.Read(tweak, c, "defender-settings.psd1");

    public TweakState Detect(Tweak tweak, TweakContext c) => c.Registry.State(Rows(tweak, c), c.System.Build);

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        Write(tweak, c, TweakMode.Apply);
        c.Registry.RemoveValue(@"HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard", "EnableVirtualizationBasedSecurity");
        var bcd = TweakServices.Need(c.Services.BcdEdit, "bcdedit");
        foreach (var v in new[] { "allowedinmemorysettings", "isolatedcontext", "hypervisorlaunchtype" }) bcd.Run($"/deletevalue {v}");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value) => Write(tweak, c, TweakMode.Revert);

    private static void Write(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var rows = Rows(tweak, c);
        DefenderRows.Write(c, rows, rows, mode, r => r.Name ?? r.Path);
        c.Registry.RemoveValue(Hvci, "ChangedInBootCycle");
    }
}
