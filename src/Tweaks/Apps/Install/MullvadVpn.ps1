# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "mullvadvpn".
@{
    Id          = 'install-mullvad-vpn'
    Name        = 'Mullvad VPN'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Private VPN. Paid; adds a network driver and a service.'
    Winget      = 'MullvadVPN.MullvadVPN'
}
