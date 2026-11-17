# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "wingetui".
@{
    Id          = 'install-unigetui'
    Name        = 'UniGetUI'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'A window over winget, Scoop and Chocolatey.'
    Winget      = 'Devolutions.UniGetUI'
}
