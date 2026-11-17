# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "jetbrains".
@{
    Id          = 'install-jetbrains-toolbox'
    Name        = 'JetBrains Toolbox'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Installs and updates JetBrains IDEs.'
    Winget      = 'JetBrains.Toolbox'
}
