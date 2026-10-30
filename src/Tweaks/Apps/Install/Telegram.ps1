# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-telegram'
    Name        = 'Telegram'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Messaging app.'
    Winget      = 'Telegram.TelegramDesktop'
}
