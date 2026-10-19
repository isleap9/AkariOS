# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-hwinfo'
    Name        = 'HWiNFO'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Hardware details and live sensors (temperatures, clocks, power).'
    Winget      = 'REALiX.HWiNFO'
}
