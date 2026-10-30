# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-winrar'
    Name        = 'WinRAR'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'File archiver (RAR and ZIP).'
    Winget      = 'RARLab.WinRAR'
}
