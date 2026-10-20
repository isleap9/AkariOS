# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\33 Defender Optimize and One-click's stepone.ps1. Defender
# guards these keys, so they are written in Safe Mode as TrustedInstaller (SafeMode: Akari takes the PC there and back).
# The values: Files\defender-settings.psd1. Turning off virtualization-based security (bcdedit) has no Revert: Windows
# turns it back on with memory integrity.
@{
    Id          = 'security-defender-settings'
    Name        = 'Windows Security: protections and notifications off'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    AkariOS     = $true
    SafeMode    = $true
    Reboot      = $true
    Description = 'Tamper, cloud and ransomware protection, Smart App Control, SmartScreen, phishing protection, exploit protection, memory integrity, LSA protection and the driver blocklist off; no security notifications. Needs Safe Mode: Akari restarts into it and back.'
    Detect      = {
        Get-AkariRegistryState @((Import-PowerShellDataFile "$AkariTweakDir\Files\defender-settings.psd1").Registry)
    }
    Apply       = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\defender-settings.psd1").Registry)
        Invoke-AkariRegistryTrusted $rows Apply
        # then as admin too (the HKCU rows are the real user's); a value Windows still guards is only logged
        foreach ($r in $rows) { try { Invoke-AkariRegistry @($r) Apply } catch { "Kept by Windows: $($r.Name) ($($_.Exception.Message))" } }
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'ChangedInBootCycle'
        # virtualization-based security (some anti-cheats force it on and leave it)
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
        foreach ($v in 'allowedinmemorysettings', 'isolatedcontext', 'hypervisorlaunchtype') { [void](Invoke-AkariBcdEdit "/deletevalue $v") }
    }
    Revert      = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\defender-settings.psd1").Registry)
        Invoke-AkariRegistryTrusted $rows Revert
        foreach ($r in $rows) { try { Invoke-AkariRegistry @($r) Revert } catch { "Kept by Windows: $($r.Name) ($($_.Exception.Message))" } }
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'ChangedInBootCycle'
    }
}
