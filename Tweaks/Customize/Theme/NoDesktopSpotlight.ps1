# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable Windows spotlight" (the desktop
# one).
@{
    Id          = 'theme-no-desktop-spotlight'
    Name        = 'No Windows spotlight on the desktop'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'The desktop stops cycling Bing pictures and drops the "Learn about this picture" icon.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings'; Name = 'EnabledState'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
