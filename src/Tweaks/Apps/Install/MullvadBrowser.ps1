# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "mullvadbrowser".
@{
    Id          = 'install-mullvad-browser'
    Name        = 'Mullvad Browser'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Privacy browser from Mullvad and the Tor Project, without Tor.'
    Winget      = 'MullvadVPN.MullvadBrowser'
}
