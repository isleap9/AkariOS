# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "protonauth".
@{
    Id          = 'install-proton-authenticator'
    Name        = 'Proton Authenticator'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Two-factor codes.'
    Winget      = 'Proton.ProtonAuthenticator'
}
