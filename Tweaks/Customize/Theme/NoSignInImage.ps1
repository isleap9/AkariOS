# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable lock screen image" (the
# "show the lock screen background picture on the sign-in screen" policy).
@{
    Id          = 'theme-no-sign-in-image'
    Name        = 'Plain colour sign-in screen'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'The sign-in screen shows the accent colour instead of the lock screen picture.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'DisableLogonBackgroundImage'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
