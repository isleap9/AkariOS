# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "hwmonitor".
@{
    Id          = 'install-hwmonitor'
    Name        = 'HWMonitor'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Temperatures, voltages and fan speeds.'
    Winget      = 'CPUID.HWMonitor'
}
