# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "yarn".
@{
    Id          = 'install-yarn'
    Name        = 'Yarn'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Languages & SDKs'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Node.js package manager. Needs Node.js.'
    Winget      = 'Yarn.Yarn'
}
