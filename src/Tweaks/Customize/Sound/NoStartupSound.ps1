# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'sound-no-startup-sound'
    Name        = 'No startup sound'
    Section     = 'Customize'
    Category    = 'Sound'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows starts silently.'
    Registry    = @(
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation'; Name = 'DisableStartupSound'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\EditionOverrides'; Name = 'UserSetting_DisableStartupSound'; Type = 'DWord'; Value = 1; Default = 0 }
    )
}
