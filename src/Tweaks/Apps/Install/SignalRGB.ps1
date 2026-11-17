# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "signalrgb".
@{
    Id          = 'install-signalrgb'
    Name        = 'SignalRGB'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'RGB lighting control. Some features are paid.'
    Winget      = 'WhirlwindFX.SignalRgb'
}
