# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable notifications": the senders
# notifications-quiet and notifications-off don't cover.
@{
    Id          = 'notifications-quiet-system'
    Name        = 'Fewer Windows notifications'
    Section     = 'Customize'
    Category    = 'Notifications'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Turns off notifications from new startup apps, the Snipping Tool, the keyboard layout switch, account health, Windows Backup and its reminders, and low disk space.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.ScreenSketch_8wekyb3d8bbwe!App'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.Windows.InputSwitchToastHandler'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.AccountHealth'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\MicrosoftWindows.Client.CBS_cw5n1h2txyewy!WindowsBackup'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.BackupReminder'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.LowDisk'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
