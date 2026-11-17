# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "thunderbird".
@{
    Id          = 'install-thunderbird'
    Name        = 'Thunderbird'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Mozilla''s mail and calendar client.'
    Winget      = 'Mozilla.Thunderbird'
}
