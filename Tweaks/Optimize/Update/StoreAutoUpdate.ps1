# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'update-store-auto-update'
    Name        = 'No automatic Store app updates'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Microsoft Store apps update only when you ask.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate'; Name = 'AutoDownload'; Type = 'DWord'; Value = 2; Default = $null }
    )
}
