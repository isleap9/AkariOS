# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-qbittorrent'
    Name        = 'qBittorrent'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Torrent client without ads.'
    Winget      = 'qBittorrent.qBittorrent'
}
