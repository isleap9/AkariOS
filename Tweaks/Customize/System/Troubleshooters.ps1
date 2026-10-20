# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-no-troubleshooters'
    Name        = 'No automatic troubleshooters'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows doesn''t run recommended troubleshooters on its own.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\WindowsMitigation'; Name = 'UserPreference'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
