# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "waterfox".
@{
    Id          = 'install-waterfox'
    Name        = 'Waterfox'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Privacy-minded Firefox fork.'
    Winget      = 'Waterfox.Waterfox'
}
