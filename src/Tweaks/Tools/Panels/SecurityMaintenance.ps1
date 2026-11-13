# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelSecurity".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-security'
    Name        = 'Security and Maintenance'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Security and Maintenance: Windows'' messages, the reliability history, automatic maintenance.'
    Apply       = { Start-Process 'wscui.cpl' }
}
