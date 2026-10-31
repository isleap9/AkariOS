# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Disable-Mitigations (zISO runs it as TrustedInstaller). MitigationOptions: 24 bytes of 0x22 (hex text, a data
# .psd1 can't hold [byte[]]).
@{
    Name        = 'Disable security mitigations'
    Description = 'Turns off the system-wide exploit mitigations, virtualization-based security, memory integrity and Credential Guard.'
    Group       = 'Security'
    Order       = 3
    Registry    = @(
        @{ Path = 'SYSTEM\ControlSet001\Control\Session Manager\kernel'; Name = 'MitigationOptions'; Type = 'Binary'; Value = '22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22'; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Control\DeviceGuard'; Name = 'EnableVirtualizationBasedSecurity'; Type = 'DWord'; Value = 0; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Control\DeviceGuard'; Name = 'HypervisorEnforcedCodeIntegrity'; Type = 'DWord'; Value = 0; Trusted = $true }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\DeviceGuard\RequirePlatformSecurityFeatures'; Name = 'value'; Type = 'DWord'; Value = 0; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Control\DeviceGuard\Scenarios\CredentialGuard'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Trusted = $true }
    )
}
