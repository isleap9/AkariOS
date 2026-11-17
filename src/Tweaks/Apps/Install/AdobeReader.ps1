# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "adobe".
@{
    Id          = 'install-adobe-reader'
    Name        = 'Adobe Acrobat Reader'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Documents'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Adobe''s PDF reader.'
    Winget      = 'Adobe.Acrobat.Reader.64-bit'
}
