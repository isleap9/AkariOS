# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "netbird".
@{
    Id          = 'install-netbird'
    Name        = 'NetBird'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Open-source private network between your devices. Adds a network driver and a service.'
    Winget      = 'Netbird.Netbird'
}
