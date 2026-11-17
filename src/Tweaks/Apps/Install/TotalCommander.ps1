# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "totalcommander".
@{
    Id          = 'install-total-commander'
    Name        = 'Total Commander'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Two-pane file manager. Shareware: asks to be paid for.'
    Winget      = 'Ghisler.TotalCommander'
}
