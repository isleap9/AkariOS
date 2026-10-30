# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings. Windows shows it by default;
# this pins it on, so a theme or a policy can't hide it.
@{
    Id          = 'explorer-desktop-recycle-bin'
    Name        = 'Recycle Bin on the desktop'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Keeps the Recycle Bin icon on the desktop.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu'; Name = '{645FF040-5081-101B-9F08-00AA002F954E}'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'; Name = '{645FF040-5081-101B-9F08-00AA002F954E}'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
