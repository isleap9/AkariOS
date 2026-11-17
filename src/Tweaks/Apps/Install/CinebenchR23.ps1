# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "cinebenchr23".
@{
    Id          = 'install-cinebench-r23'
    Name        = 'Cinebench R23'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'CPU render benchmark.'
    Winget      = 'Maxon.CinebenchR23'
}
