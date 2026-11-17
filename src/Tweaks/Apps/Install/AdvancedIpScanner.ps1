# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "advancedip".
@{
    Id          = 'install-advanced-ip-scanner'
    Name        = 'Advanced IP Scanner'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Finds the devices on your network and their open shares.'
    Winget      = 'Famatech.AdvancedIPScanner'
}
