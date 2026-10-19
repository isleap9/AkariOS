# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-vivaldi'
    Name        = 'Vivaldi'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Chromium-based browser with a built-in ad blocker.'
    Winget      = 'Vivaldi.Vivaldi'
}
