# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-librewolf'
    Name        = 'LibreWolf'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Privacy-focused Firefox fork, uBlock Origin built in.'
    Winget      = 'LibreWolf.LibreWolf'
}
