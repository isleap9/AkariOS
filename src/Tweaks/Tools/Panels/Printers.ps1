# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelPrinter".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-printers'
    Name        = 'Printers'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens the classic Printers folder (Devices and Printers'' printer list).'
    Apply       = { Start-Process 'explorer.exe' -ArgumentList 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}' }
}
