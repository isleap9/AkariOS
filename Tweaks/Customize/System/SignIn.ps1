# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-password-sign-in'
    Name        = 'Password sign-in, no automatic sign-in'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The password option stays available next to Windows Hello; no automatic sign-in after an update; no dynamic lock.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'; Name = 'EnableGoodbye'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'DisableAutomaticRestartSignOn'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'; Name = 'DevicePasswordLessBuildVersion'; Type = 'DWord'; Value = 0; Default = 2 }
        @{ Path = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'; Name = 'DevicePasswordLessUpdateType'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
