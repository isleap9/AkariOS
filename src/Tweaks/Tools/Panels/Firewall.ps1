# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelFirewall".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-firewall'
    Name        = 'Windows Defender Firewall'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens the classic Windows Defender Firewall panel: on / off per network, allowed apps, advanced rules.'
    Apply       = { Start-Process 'firewall.cpl' }
}
