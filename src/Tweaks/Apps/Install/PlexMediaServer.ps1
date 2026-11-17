# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "plex".
@{
    Id          = 'install-plex-media-server'
    Name        = 'Plex Media Server'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Home server & streaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Media server for your films, shows and music. Some features are paid; runs in the background.'
    Winget      = 'Plex.PlexMediaServer'
}
