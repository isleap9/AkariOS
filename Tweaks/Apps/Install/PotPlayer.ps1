# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-pot-player'
    Name        = 'PotPlayer'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Video and audio player.'
    Winget      = 'Daum.PotPlayer'
}
