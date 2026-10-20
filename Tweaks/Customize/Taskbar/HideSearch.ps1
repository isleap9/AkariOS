# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar.
@{
    Id          = 'taskbar-hide-search'
    Name        = 'Hide Search on the taskbar'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Removes the search box or icon. Search still opens when you type in Start.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Type = 'DWord'; Value = 0; Default = $null }
}
