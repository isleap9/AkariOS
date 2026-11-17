# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "policyplus".
@{
    Id          = 'install-policy-plus'
    Name        = 'Policy Plus'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Group policy editor that works on Home too.'
    Winget      = 'Fleex255.PolicyPlus'
}
