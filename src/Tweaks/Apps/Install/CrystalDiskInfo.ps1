# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "crystaldiskinfo".
@{
    Id          = 'install-crystaldiskinfo'
    Name        = 'CrystalDiskInfo'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Drive health (S.M.A.R.T.).'
    Winget      = 'CrystalDewWorld.CrystalDiskInfo'
}
