# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "ntlite".
@{
    Id          = 'install-ntlite'
    Name        = 'NTLite'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Edits Windows images. Free for personal use, paid tiers.'
    Winget      = 'Nlitesoft.NTLite'
}
