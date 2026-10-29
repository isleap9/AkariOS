# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable Windows widgets": the lock screen
# values taskbar-disable-widgets doesn't set. Its two Dsh policy values are left out: ZOICWARE sets them to 0, which is
# what Windows does with no policy.
@{
    Id          = 'theme-no-lock-screen-widgets'
    Name        = 'No widgets on the lock screen'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Description = 'The lock screen stops showing weather, stocks and other widgets.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen'; Name = 'AutoSelectWidgetsOnLockScreen'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen'; Name = 'LockScreenWidgetsEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
