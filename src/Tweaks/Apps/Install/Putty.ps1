# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "putty".
@{
    Id          = 'install-putty'
    Name        = 'PuTTY'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'SSH and serial terminal.'
    Winget      = 'PuTTY.PuTTY'
}
