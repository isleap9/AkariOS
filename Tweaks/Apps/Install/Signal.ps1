# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-signal'
    Name        = 'Signal'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Encrypted messaging app.'
    Winget      = 'OpenWhisperSystems.Signal'
}
