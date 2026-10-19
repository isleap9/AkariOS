# Action: an installed app is removed with its own uninstaller (or the Apps step's Remove tab); Akari has no Revert for it.
# Not winget: winget installs Store apps through the Store itself. Ported from FR33THY Ultimate "bloatware" (Install Store).
@{
    Id          = 'install-microsoft-store'
    Name        = 'Microsoft Store'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Restore removed apps'
    # listed in the restore card only while this package is missing
    Package     = 'Microsoft.WindowsStore'
    StoreId     = '9WZDNCRFJBMP'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Brings the Microsoft Store back after a debloat: registers it again, or has Windows download it (wsreset -i).'
    Detect      = { Test-AkariAppxInstalled 'Microsoft.WindowsStore' }
    Apply       = { Install-AkariMicrosoftStore }
}
