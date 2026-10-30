# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'update-maps-auto-update'
    Name        = 'No automatic map updates'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Offline maps don''t update in the background.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\Maps'; Name = 'AutoUpdateEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
