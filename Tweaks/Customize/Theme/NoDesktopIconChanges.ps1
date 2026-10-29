# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable allow themes to change desktop
# icons".
@{
    Id          = 'theme-no-desktop-icon-changes'
    Name        = 'Themes keep the desktop icons'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Switching themes no longer swaps the desktop icons (This PC, Recycle Bin and the rest) for the theme''s own.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes'; Name = 'ThemeChangesDesktopIcons'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
