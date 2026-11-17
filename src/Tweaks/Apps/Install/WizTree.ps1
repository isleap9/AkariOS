# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "wiztree".
@{
    Id          = 'install-wiztree'
    Name        = 'WizTree'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Fast disk space view. Free for personal use.'
    Winget      = 'AntibodySoftware.WizTree'
}
