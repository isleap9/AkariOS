# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\6 Signout Lockscreen Wallpaper Black.
@{
    Id          = 'theme-no-signin-blur'
    Name        = 'No blur on the sign-in screen'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The sign-in screen shows its background sharp instead of blurred.'
    Registry    = @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'DisableAcrylicBackgroundOnLogon'; Type = 'DWord'; Value = 1; Default = $null }
}
