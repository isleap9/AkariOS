# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-battle-net'
    Name        = 'Battle.net'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Blizzard''s game launcher. Akari stops it from starting with Windows.'
    Winget      = 'Blizzard.BattleNet'
    After       = { Remove-AkariStartup 'Battle.net' }
}
