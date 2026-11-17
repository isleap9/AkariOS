# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "winscp".
@{
    Id          = 'install-winscp'
    Name        = 'WinSCP'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'SFTP, FTP and SCP file transfers.'
    Winget      = 'WinSCP.WinSCP'
}
