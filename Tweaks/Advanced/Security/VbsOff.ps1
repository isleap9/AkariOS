# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable core isolation (VBS)", without
# memory integrity itself (HypervisorEnforcedCodeIntegrity Enabled / WasEnabledBy: security-defender-settings owns them).
# security-defender-settings also deletes DeviceGuard\EnableVirtualizationBasedSecurity when applied.
@{
    Id          = 'security-vbs-off'
    Name        = 'Turn off virtualization-based security'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns off VBS, Credential Guard and kernel shadow stacks by policy: a little less overhead in games, much less protection against kernel attacks. Some anti-cheats need VBS on.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'EnableVirtualizationBasedSecurity'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'RequirePlatformSecurityFeatures'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'Mandatory'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'HypervisorEnforcedCodeIntegrity'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard'; Name = 'EnableVirtualizationBasedSecurity'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard'; Name = 'LsaCfgFlags'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks'; Name = 'AuditModeEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Security Health\Miscellaneous'; Name = 'HvciKeyDismissed'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
