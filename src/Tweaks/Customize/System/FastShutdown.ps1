# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Enable Fast Shutdown/Restart": shorter
# waits for apps and services that don't close. Revert: the two per-user values deleted (Windows has none), the
# service timeout back to Windows' 5000 ms.
@{
    Id          = 'system-fast-shutdown'
    Name        = 'Faster shut down and restart'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'At shut down, apps and services that don''t close get 1.5 seconds instead of 5 or more, then are ended. Unsaved work in an app that hangs is lost.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'WaitToKillAppTimeout'; Type = 'String'; Value = '1500'; Default = $null }
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'AutoEndTasks'; Type = 'String'; Value = '1'; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control'; Name = 'WaitToKillServiceTimeout'; Type = 'String'; Value = '1500'; Default = '5000' }
    )
}
