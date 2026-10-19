# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-vscode'
    Name        = 'Visual Studio Code'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Code editor.'
    Winget      = 'Microsoft.VisualStudioCode'
}
