# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "vrdesktopstreamer".
@{
    Id          = 'install-virtual-desktop-streamer'
    Name        = 'Virtual Desktop Streamer'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'PC side of Virtual Desktop for Quest headsets. The headset app is paid.'
    Winget      = 'VirtualDesktop.Streamer'
}
