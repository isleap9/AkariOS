# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-whatsapp'
    Name        = 'WhatsApp'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Messaging app (from the Microsoft Store).'
    Winget      = '9NKSQGP7F2NH'
    WingetSource = 'msstore'
}
