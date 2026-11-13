# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelNetwork".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-network'
    Name        = 'Network Connections'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Network Connections: every adapter, its properties, IP and DNS settings.'
    Apply       = { Start-Process 'ncpa.cpl' }
}
