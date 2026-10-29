# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable system requirements".
@{
    Id          = 'system-skip-win11-requirements'
    Name        = 'Skip Windows 11''s hardware checks for upgrades'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Setup and feature updates skip the TPM, Secure Boot, CPU, RAM and storage checks, and the "unsupported hardware" watermark goes. Microsoft may not offer updates to such PCs.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV2'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\Setup\LabConfig'; Name = 'BypassCPUCheck'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\Setup\LabConfig'; Name = 'BypassRAMCheck'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\Setup\LabConfig'; Name = 'BypassSecureBootCheck'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\Setup\LabConfig'; Name = 'BypassStorageCheck'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\Setup\LabConfig'; Name = 'BypassTPMCheck'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\Setup\MoSetup'; Name = 'AllowUpgradesWithUnsupportedTPMOrCPU'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
