# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "geforcenow".
@{
    Id          = 'install-geforce-now'
    Name        = 'GeForce NOW'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Game launchers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'NVIDIA''s cloud gaming.'
    Winget      = 'Nvidia.GeForceNow'
}
