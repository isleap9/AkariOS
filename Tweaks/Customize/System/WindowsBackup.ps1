# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-no-windows-backup'
    Name        = 'No Windows Backup and settings sync'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Windows doesn''t back up or sync your settings, apps and passwords to your Microsoft account.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableAccessibilitySettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableAccessibilitySettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableAppSyncSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableAppSyncSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableApplicationSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableApplicationSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableCredentialsSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableCredentialsSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableDesktopThemeSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableDesktopThemeSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableLanguageSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableLanguageSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisablePersonalizationSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisablePersonalizationSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableStartLayoutSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableStartLayoutSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableSyncOnPaidNetwork'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableWebBrowserSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableWebBrowserSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableWindowsSettingSync'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'DisableWindowsSettingSyncUserOverride'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; Name = 'EnableWindowsBackup'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\ControlSet001\Services\CDPUserSvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 2 }
    )
}
