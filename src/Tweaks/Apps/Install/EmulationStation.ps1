# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "es-de".
@{
    Id          = 'install-emulationstation'
    Name        = 'EmulationStation Desktop Edition'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Front end for emulators.'
    Winget      = 'ES-DE.EmulationStation-DE'
}
