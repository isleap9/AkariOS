# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-foobar2000'
    Name        = 'foobar2000'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Lightweight music player.'
    Winget      = 'PeterPawlowski.foobar2000'
}
