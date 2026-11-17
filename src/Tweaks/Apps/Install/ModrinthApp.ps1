# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "modrinth".
@{
    Id          = 'install-modrinth-app'
    Name        = 'Modrinth App'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Minecraft mod launcher.'
    Winget      = 'Modrinth.ModrinthApp'
}
