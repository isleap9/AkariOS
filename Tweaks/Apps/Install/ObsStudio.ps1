# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-obs-studio'
    Name        = 'OBS Studio'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Screen recording and live streaming.'
    Winget      = 'OBSProject.OBSStudio'
}
