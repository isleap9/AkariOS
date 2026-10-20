# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'notifications-no-suggestions'
    Name        = 'No suggested actions'
    Section     = 'Customize'
    Category    = 'Notifications'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'No suggestion pop-ups and no actions offered when you copy a date or phone number.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard'; Name = 'Disabled'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
