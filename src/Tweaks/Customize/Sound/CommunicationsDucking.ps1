# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'sound-communications-do-nothing'
    Name        = 'Calls don''t lower other sounds'
    Section     = 'Customize'
    Category    = 'Sound'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Game and music volume stay the same during calls.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Multimedia\Audio'; Name = 'UserDuckingPreference'; Type = 'DWord'; Value = 3; Default = $null }
    )
}
