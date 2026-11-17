# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "heroiclauncher".
@{
    Id          = 'install-heroic-games'
    Name        = 'Heroic Games Launcher'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Open-source launcher for Epic, GOG and Amazon games.'
    Winget      = 'HeroicGamesLauncher.HeroicGamesLauncher'
}
