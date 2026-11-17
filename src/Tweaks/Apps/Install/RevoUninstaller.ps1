# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "revo".
@{
    Id          = 'install-revo-uninstaller'
    Name        = 'Revo Uninstaller'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Uninstaller that cleans leftovers.'
    Winget      = 'RevoUninstaller.RevoUninstaller'
}
