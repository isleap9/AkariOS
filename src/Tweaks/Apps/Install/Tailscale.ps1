# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "tailscale".
@{
    Id          = 'install-tailscale'
    Name        = 'Tailscale'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Private network between your devices, on WireGuard. Adds a network driver and a service.'
    Winget      = 'Tailscale.Tailscale'
}
