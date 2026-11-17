# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "dockerdesktop".
@{
    Id          = 'install-docker-desktop'
    Name        = 'Docker Desktop'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Containers. Needs WSL. Paid for larger companies.'
    Winget      = 'Docker.DockerDesktop'
}
