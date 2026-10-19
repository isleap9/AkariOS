# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-epic-games'
    Name        = 'Epic Games Launcher'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Epic Games'' store and launcher. Akari stops it from starting with Windows.'
    Winget      = 'EpicGames.EpicGamesLauncher'
    After       = { Remove-AkariStartup 'EpicGamesLauncher' }
}
