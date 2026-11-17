# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "protonmail".
@{
    Id          = 'install-proton-mail'
    Name        = 'Proton Mail'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Encrypted mail desktop app.'
    Winget      = 'Proton.ProtonMail'
}
