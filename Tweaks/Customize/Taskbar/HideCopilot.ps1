# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar. Copilot itself (app and policy)
# is a Privacy Toggle.
@{
    Id          = 'taskbar-hide-copilot'
    Name        = 'Hide Copilot on the taskbar'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Removes the Copilot button from the taskbar.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Type = 'DWord'; Value = 0; Default = $null }
}
