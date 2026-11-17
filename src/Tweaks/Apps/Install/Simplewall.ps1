# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "simplewall".
@{
    Id          = 'install-simplewall'
    Name        = 'simplewall'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Firewall that blocks every app until you allow it. Can cut programs off the network.'
    Winget      = 'Henry++.simplewall'
}
