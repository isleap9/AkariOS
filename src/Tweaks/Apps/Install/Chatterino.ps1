# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "chatterino".
@{
    Id          = 'install-chatterino'
    Name        = 'Chatterino'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Twitch chat client.'
    Winget      = 'ChatterinoTeam.Chatterino'
}
