# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar.
@{
    Id          = 'taskbar-hide-meet-now'
    Name        = 'Hide Meet Now'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win10'
    Explorer    = $true
    Description = 'Removes the Skype Meet Now icon from the notification area.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'HideSCAMeetNow'; Type = 'DWord'; Value = 1; Default = $null }
}
