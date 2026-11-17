# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "nmap".
@{
    Id          = 'install-nmap'
    Name        = 'Nmap'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Network and port scanner. Adds the Npcap capture driver.'
    Winget      = 'Insecure.Nmap'
}
