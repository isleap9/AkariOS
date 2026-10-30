# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\3 Spectre Meltdown.
@{
    Id          = 'security-spectre-meltdown-off'
    Name        = 'Turn off Spectre and Meltdown protection'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    Reboot      = $true
    Description = 'Turns off the CPU side-channel mitigations. Faster on older CPUs, but less safe.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'FeatureSettingsOverrideMask'; Type = 'DWord'; Value = 3; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'FeatureSettingsOverride'; Type = 'DWord'; Value = 3; Default = $null }
    )
}
