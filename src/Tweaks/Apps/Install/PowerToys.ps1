# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-powertoys'
    Name        = 'PowerToys'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Microsoft''s power-user tools (FancyZones, PowerToys Run, color picker...).'
    Winget      = 'Microsoft.PowerToys'
}
