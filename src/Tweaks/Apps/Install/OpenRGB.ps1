# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "openrgb".
@{
    Id          = 'install-openrgb'
    Name        = 'OpenRGB'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'One app for every brand''s RGB lighting. Uses a low-level hardware driver.'
    Winget      = 'OpenRGB.OpenRGB'
}
