# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'update-delivery-optimization'
    Name        = 'No update sharing'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows Update downloads only from Microsoft, never from or to other PCs.'
    Registry    = @(
        @{ Path = 'Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings'; Name = 'DownloadMode'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
