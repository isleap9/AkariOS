# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "fileconverter".
@{
    Id          = 'install-file-converter'
    Name        = 'File Converter'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Converts files from the right-click menu.'
    Winget      = 'AdrienAllard.FileConverter'
}
