# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-nanazip'
    Name        = 'NanaZip'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = '7-Zip with the Windows 11 right-click menu.'
    Winget      = 'M2Team.NanaZip'
}
