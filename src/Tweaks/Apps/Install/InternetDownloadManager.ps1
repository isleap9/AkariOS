# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "internetdownloadmanager".
@{
    Id          = 'install-internet-download-manager'
    Name        = 'Internet Download Manager'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Download manager. Paid after a 30-day trial.'
    Winget      = 'Tonec.InternetDownloadManager'
}
