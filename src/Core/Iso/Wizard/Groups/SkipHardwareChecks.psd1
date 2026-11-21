# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): Windows 11 setup's hardware
# checks skipped. Rows: Path starts with the image's hive (SOFTWARE, SYSTEM, NTUSER = the default user, DEFAULT).
# Registry = install.wim, Boot = boot.wim's setup image. The LabConfig and MoSetup values are the ones Microsoft and
# the community document for setup on unsupported hardware; the same rows zISO Tweaker writes (MIT, CREDITS.md).
@{
    Name        = 'Skip the hardware checks'
    Description = 'Setup and upgrades run on PCs without TPM 2.0, Secure Boot or a supported CPU, and Windows doesn''t nag about it.'
    Kind        = 'Setup'
    Risk        = 'Safe'
    Order       = 1
    Registry    = @(
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassCPUCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassRAMCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassSecureBootCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassStorageCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassTPMCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\MoSetup'; Name = 'AllowUpgradesWithUnsupportedTPMOrCPU'; Type = 'DWord'; Value = 1 }
        @{ Path = 'DEFAULT\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV1'; Type = 'DWord'; Value = 0 }
        @{ Path = 'DEFAULT\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV2'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV1'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV2'; Type = 'DWord'; Value = 0 }
    )
    Boot        = @(
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassCPUCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassRAMCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassSecureBootCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassStorageCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassTPMCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\MoSetup'; Name = 'AllowUpgradesWithUnsupportedTPMOrCPU'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\Status\ChildCompletion'; Name = 'setup.exe'; Type = 'DWord'; Value = 3 }
    )
}
