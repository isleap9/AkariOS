# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "Ruby".
@{
    Id          = 'install-ruby'
    Name        = 'Ruby'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Languages & SDKs'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'The Ruby language.'
    Winget      = 'RubyInstallerTeam.Ruby.4.0'
}
