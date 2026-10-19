# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-electronic-arts'
    Name        = 'EA app'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Electronic Arts'' game launcher. Akari stops it from starting with Windows.'
    Winget      = 'ElectronicArts.EADesktop'
    After       = { Remove-AkariStartup 'EADM' }
}
