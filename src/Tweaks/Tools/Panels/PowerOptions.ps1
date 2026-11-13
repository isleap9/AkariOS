# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelPower".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-power'
    Name        = 'Power Options'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens the classic Power Options: the power plans and their advanced settings.'
    Apply       = { Start-Process 'powercfg.cpl' }
}
