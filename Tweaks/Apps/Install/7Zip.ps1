# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-7-zip'
    Name        = '7-Zip'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'File archiver. Akari keeps its right-click menu short (Open archive, Extract, Add to archive).'
    Winget      = '7zip.7zip'
    After       = {
        # flat context menu with the common commands only
        Set-Reg 'HKCU:\Software\7-Zip\Options' 'ContextMenu' 259
        Set-Reg 'HKCU:\Software\7-Zip\Options' 'CascadedMenu' 0
    }
}
