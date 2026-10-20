# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'privacy-find-my-device'
    Name        = 'Find my device off'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'This PC no longer reports its location to your Microsoft account.'
    Registry    = @(
        @{ Path = 'HKLM:\Software\Microsoft\MdmCommon\SettingValues'; Name = 'LocationSyncEnabled'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
