# Action: an installed app is removed with its own uninstaller (or the Apps step's Remove tab); Akari has no Revert for it.
# Ported from FR33THY Ultimate "bloatware" (Install: One Drive); now from winget.
@{
    Id          = 'install-onedrive'
    Name        = 'OneDrive'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Restore removed apps'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Brings OneDrive back after a debloat: Microsoft''s cloud file sync.'
    Winget      = 'Microsoft.OneDrive'
}
