# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "xournal".
@{
    Id          = 'install-xournalpp'
    Name        = 'Xournal++'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Documents'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Handwritten notes and PDF annotation.'
    Winget      = 'Xournal++.Xournal++'
}
