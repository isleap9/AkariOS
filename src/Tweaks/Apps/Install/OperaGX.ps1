# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-opera-gx'
    Name        = 'Opera GX'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Opera''s gaming browser, with RAM and CPU limiters.'
    Winget      = 'Opera.OperaGX'
}
