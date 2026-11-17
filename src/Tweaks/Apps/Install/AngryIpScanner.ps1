# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "angryipscanner".
@{
    Id          = 'install-angry-ip-scanner'
    Name        = 'Angry IP Scanner'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Fast IP and port scanner for your network.'
    Winget      = 'angryziber.AngryIPScanner'
}
