# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Show big clock in notification center".
@{
    Id          = 'notifications-big-clock'
    Name        = 'Big clock in the notification center'
    Section     = 'Customize'
    Category    = 'Notifications'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'The notification center shows the time, with seconds, above the calendar. Recent Windows 11 builds only.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowClockInNotificationCenter'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
