# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'taskbar-far-corner-desktop'
    Name        = 'Far corner shows the desktop'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Click the far right corner of the taskbar to show the desktop.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarSd'; Type = 'DWord'; Value = 1; Default = $null }
}
