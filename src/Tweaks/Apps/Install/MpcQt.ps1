# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "mpc-qt".
@{
    Id          = 'install-mpc-qt'
    Name        = 'mpc-qt'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'MPC-like player built on mpv.'
    Winget      = 'mpc-qt.mpc-qt'
}
