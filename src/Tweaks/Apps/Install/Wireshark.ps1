# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "wireshark".
@{
    Id          = 'install-wireshark'
    Name        = 'Wireshark'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Network & remote'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Captures and reads network traffic. Live capture needs the Npcap driver.'
    Winget      = 'WiresharkFoundation.Wireshark'
}
