# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "sublimetext".
@{
    Id          = 'install-sublime-text'
    Name        = 'Sublime Text'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Text editor. Asks to be paid for.'
    Winget      = 'SublimeHQ.SublimeText.4'
}
