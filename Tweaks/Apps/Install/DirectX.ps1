# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-directx'
    Name        = 'DirectX End-User Runtime'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Runtimes'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'The older DirectX 9-11 files many games still need.'
    Winget      = 'Microsoft.DirectX'
}
