# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "pdf24creator".
@{
    Id          = 'install-pdf24'
    Name        = 'PDF24 Creator'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Documents'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'PDF tools and a PDF printer.'
    Winget      = 'geeksoftwareGmbH.PDF24Creator'
}
