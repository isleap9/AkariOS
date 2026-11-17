# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "powershell".
@{
    Id          = 'install-powershell'
    Name        = 'PowerShell 7'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'The current PowerShell, next to Windows'' 5.1.'
    Winget      = 'Microsoft.PowerShell'
}
