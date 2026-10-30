# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-git'
    Name        = 'Git'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Version control, with Git Bash.'
    Winget      = 'Git.Git'
}
