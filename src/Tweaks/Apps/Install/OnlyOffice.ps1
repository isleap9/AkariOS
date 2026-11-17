# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "onlyoffice".
@{
    Id          = 'install-onlyoffice'
    Name        = 'ONLYOFFICE'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Documents'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Office suite.'
    Winget      = 'ONLYOFFICE.DesktopEditors'
}
