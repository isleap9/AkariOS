# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-mpv'
    Name        = 'mpv'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Minimal, high-quality video player.'
    Winget      = 'shinchiro.mpv'
}
