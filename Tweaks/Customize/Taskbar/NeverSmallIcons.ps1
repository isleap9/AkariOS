# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'taskbar-never-small-icons'
    Name        = 'Never shrink taskbar icons'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Taskbar icons stay full size even when the taskbar is full.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'IconSizePreference'; Type = 'DWord'; Value = 1; Default = $null }
}
