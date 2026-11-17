# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "processmonitor".
@{
    Id          = 'install-process-monitor'
    Name        = 'Process Monitor'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Sysinternals'' file, registry and process trace.'
    Winget      = 'Microsoft.Sysinternals.ProcessMonitor'
}
