# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "visualstudio2022".
@{
    Id          = 'install-visual-studio-2022'
    Name        = 'Visual Studio 2022 Community'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Microsoft''s IDE, 2022.'
    Winget      = 'Microsoft.VisualStudio.2022.Community'
}
