# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelSystem".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-system'
    Name        = 'System Properties'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens System Properties: the PC''s name, performance options and virtual memory, System Protection, remote access.'
    Apply       = { Start-Process 'sysdm.cpl' }
}
