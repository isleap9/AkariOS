# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-python'
    Name        = 'Python 3'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Python 3.14.'
    Winget      = 'Python.Python.3.14'
}
