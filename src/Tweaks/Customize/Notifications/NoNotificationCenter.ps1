# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksDisableNotifications"
# (its policy; the pop-ups are notifications-off).
@{
    Id          = 'notifications-no-center'
    Name        = 'No notification center and calendar'
    Section     = 'Customize'
    Category    = 'Notifications'
    Risk        = 'Caution'
    Guided      = $false
    Explorer    = $true
    Description = 'Group policy removes the notification center and the calendar flyout from the taskbar clock. Notifications you miss are gone.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableNotificationCenter'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
