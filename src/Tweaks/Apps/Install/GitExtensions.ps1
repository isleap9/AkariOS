# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "gitextensions".
@{
    Id          = 'install-git-extensions'
    Name        = 'Git Extensions'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Git in a window.'
    Winget      = 'GitExtensionsTeam.GitExtensions'
}
