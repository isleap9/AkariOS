# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-nodejs'
    Name        = 'Node.js LTS'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'JavaScript runtime and npm.'
    Winget      = 'OpenJS.NodeJS.LTS'
}
