# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "mpchc".
@{
    Id          = 'install-mpc-hc'
    Name        = 'MPC-HC'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Media Player Classic, Home Cinema.'
    Winget      = 'clsid2.mpc-hc'
}
