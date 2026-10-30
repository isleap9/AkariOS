# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "Updates Drivers Block", Driver updates: Block / Unblock.
# Group policies (Pro and up; Home ignores them); update-no-driver-updates owns the non-policy values. Its
# "Block (Bootable USB)" option is not ported: it only put a setupcomplete.cmd that restarts the PC on the stick.
@{
    Id          = 'update-block-driver-updates-policy'
    Name        = 'Block driver updates (group policy)'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Advanced'
    Requires    = 'Pro'
    Guided      = $false
    Description = 'Windows Update and device setup never download drivers, device info or optional updates. Install drivers yourself (Tools > Drivers).'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata'; Name = 'PreventDeviceMetadataFromNetwork'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings'; Name = 'DisableSendGenericDriverNotFoundToWER'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings'; Name = 'DisableSendRequestAdditionalSoftwareToWER'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching'; Name = 'SearchOrderConfig'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetAllowOptionalContent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'AllowTemporaryEnterpriseFeatureControl'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'ExcludeWUDriversInQualityUpdate'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'IncludeRecommendedUpdates'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'EnableFeaturedSoftware'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
