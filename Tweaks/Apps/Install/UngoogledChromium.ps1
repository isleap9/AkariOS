# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-ungoogled-chromium'
    Name        = 'Ungoogled Chromium'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Chromium without Google''s services.'
    Winget      = 'eloston.ungoogled-chromium'
}
