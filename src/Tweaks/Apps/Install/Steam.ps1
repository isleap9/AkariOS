# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-steam'
    Name        = 'Steam'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Valve''s game store and launcher. Akari stops it from starting with Windows.'
    Winget      = 'Valve.Steam'
    After       = { Remove-AkariStartup 'Steam' }
}
