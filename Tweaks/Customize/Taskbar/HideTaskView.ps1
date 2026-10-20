# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar.
@{
    Id          = 'taskbar-hide-task-view'
    Name        = 'Hide Task view on the taskbar'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Removes the Task view button. Win+Tab still opens it.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; Type = 'DWord'; Value = 0; Default = $null }
}
