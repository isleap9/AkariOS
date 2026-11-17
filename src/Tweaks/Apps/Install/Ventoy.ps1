# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "ventoy".
@{
    Id          = 'install-ventoy'
    Name        = 'Ventoy'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Boots many ISOs from one USB drive. Installing it wipes the drive.'
    Winget      = 'Ventoy.Ventoy'
}
