# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelRegion".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-region'
    Name        = 'Region'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens the classic Region dialog: formats, location, the system locale for non-Unicode programs.'
    Apply       = { Start-Process 'intl.cpl' }
}
