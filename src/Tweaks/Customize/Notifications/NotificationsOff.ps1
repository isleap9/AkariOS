# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'notifications-off'
    Name        = 'Notifications off'
    Section     = 'Customize'
    Category    = 'Notifications'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'No pop-up notifications from apps or Windows. The notification center still collects them.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Name = 'ToastEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
