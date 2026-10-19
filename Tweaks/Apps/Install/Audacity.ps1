# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-audacity'
    Name        = 'Audacity'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Audio recording and editing.'
    Winget      = 'Audacity.Audacity'
}
