# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "githubcli".
@{
    Id          = 'install-github-cli'
    Name        = 'GitHub CLI'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'gh, GitHub from the terminal.'
    Winget      = 'GitHub.cli'
}
