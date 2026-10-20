# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\5 Theme Black.
@{
    Id          = 'theme-no-transparency'
    Name        = 'No transparency'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Solid taskbar, Start and windows instead of see-through ones.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Type = 'DWord'; Value = 0; Default = 1 }
}
