# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "tcpview".
@{
    Id          = 'install-tcpview'
    Name        = 'TCPView'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Sysinternals'' live list of connections.'
    Winget      = 'Microsoft.Sysinternals.TCPView'
}
