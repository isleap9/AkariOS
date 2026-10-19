# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-bulk-crap-uninstaller'
    Name        = 'Bulk Crap Uninstaller'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Uninstalls many apps at once, with leftovers.'
    Winget      = 'Klocman.BulkCrapUninstaller'
}
