# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "jellyfinmediaplayer".
@{
    Id          = 'install-jellyfin-media-player'
    Name        = 'Jellyfin Media Player'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Home server & streaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Plays from a Jellyfin server.'
    Winget      = 'Jellyfin.JellyfinMediaPlayer'
}
