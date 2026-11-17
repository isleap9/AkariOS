# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "sunshine".
@{
    Id          = 'install-sunshine'
    Name        = 'Sunshine'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Home server & streaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Streams this PC''s games to Moonlight. Adds a service and virtual input drivers.'
    Winget      = 'LizardByte.Sunshine'
}
