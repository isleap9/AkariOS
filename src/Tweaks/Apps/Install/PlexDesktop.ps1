# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "plexdesktop".
@{
    Id          = 'install-plex-desktop'
    Name        = 'Plex Desktop'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Home server & streaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Plays from a Plex server.'
    Winget      = 'Plex.Plex'
}
