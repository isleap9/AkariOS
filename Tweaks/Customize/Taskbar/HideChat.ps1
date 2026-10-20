# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar.
@{
    Id          = 'taskbar-hide-chat'
    Name        = 'Hide Chat on the taskbar'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Removes the Teams Chat button (early Windows 11 builds).'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarMn'; Type = 'DWord'; Value = 0; Default = $null }
}
