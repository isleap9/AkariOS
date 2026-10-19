# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-zen-browser'
    Name        = 'Zen Browser'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Firefox-based browser with vertical tabs.'
    Winget      = 'Zen-Team.Zen-Browser'
}
