# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-gog-launcher'
    Name        = 'GOG GALAXY'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'GOG''s game launcher. Akari stops it from starting with Windows.'
    Winget      = 'GOG.Galaxy'
    After       = { Remove-AkariStartup 'GalaxyClient', 'GogGalaxy' }
}
