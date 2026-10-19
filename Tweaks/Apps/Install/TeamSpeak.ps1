# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-teamspeak'
    Name        = 'TeamSpeak 3'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Voice chat for gaming.'
    Winget      = 'TeamSpeakSystems.TeamSpeakClient'
}
