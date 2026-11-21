# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "sdio"
# (Snappy Driver Installer Origin, from winget). A Tools button, not a Downloads card: it can install drivers over the
# ones AkariOS sets (the GPU driver), so it says so and is Caution.
# Action: it opens a tool; the drivers it installs are the user's own picks.
@{
    Id          = 'tools-snappy-driver-installer'
    Name        = 'Snappy Driver Installer'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Caution'
    Description = 'Opens Snappy Driver Installer Origin (installed first if missing): finds newer drivers for every device and installs the ones you tick. Leave the graphics driver unticked: use the driver buttons above for it.'
    Apply       = { Open-AkariWingetTool 'GlennDelahoy.SnappyDriverInstallerOrigin' 'SDIO_x64_*.exe' }
}
