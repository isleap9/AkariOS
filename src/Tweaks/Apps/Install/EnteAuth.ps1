# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "enteauth".
@{
    Id          = 'install-ente-auth'
    Name        = 'Ente Auth'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Two-factor codes, end-to-end encrypted.'
    Winget      = 'ente-io.auth-desktop'
}
