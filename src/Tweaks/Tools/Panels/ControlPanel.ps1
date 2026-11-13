# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelControl".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-control'
    Name        = 'Control Panel'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens the classic Control Panel.'
    Apply       = { Start-Process 'control.exe' }
}
