# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "OpenVPN".
@{
    Id          = 'install-openvpn-connect'
    Name        = 'OpenVPN Connect'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Client for OpenVPN servers. Adds a network driver and a service.'
    Winget      = 'OpenVPNTechnologies.OpenVPNConnect'
}
