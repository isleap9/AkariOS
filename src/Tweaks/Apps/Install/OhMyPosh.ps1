# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "posh".
@{
    Id          = 'install-oh-my-posh'
    Name        = 'Oh My Posh'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Shell prompt themes.'
    Winget      = 'JanDeDobbeleer.OhMyPosh'
}
