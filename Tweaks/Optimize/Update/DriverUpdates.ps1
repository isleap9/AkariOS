# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'update-no-driver-updates'
    Name        = 'No drivers from Windows Update'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'Windows Update stops replacing your drivers (keep the GPU driver you installed). Install drivers yourself.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata'; Name = 'PreventDeviceMetadataFromNetwork'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'; Name = 'SearchOrderConfig'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
