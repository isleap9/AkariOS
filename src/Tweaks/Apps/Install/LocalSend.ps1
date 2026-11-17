# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "localsend".
@{
    Id          = 'install-localsend'
    Name        = 'LocalSend'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Home server & streaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Sends files to nearby devices over your network, no account.'
    Winget      = 'LocalSend.LocalSend'
}
