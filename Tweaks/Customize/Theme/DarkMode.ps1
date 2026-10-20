# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\5 Theme Black. Default: Windows 11 is light everywhere;
# Windows 10 has a dark taskbar and Start with light apps.
@{
    Id          = 'theme-dark-mode'
    Name        = 'Dark mode'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Dark Windows and dark apps.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Type = 'DWord'; Value = 0; Default = @{ Win10 = 0; Win11 = 1 } }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
