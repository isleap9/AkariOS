# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "jellyfinserver".
@{
    Id          = 'install-jellyfin-server'
    Name        = 'Jellyfin Server'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Home server & streaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Free media server for your films, shows and music. Runs in the background.'
    Winget      = 'Jellyfin.Server'
}
