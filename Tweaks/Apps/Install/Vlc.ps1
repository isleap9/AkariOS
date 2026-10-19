# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-vlc'
    Name        = 'VLC'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Plays almost any video and audio file.'
    Winget      = 'VideoLAN.VLC'
}
