# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelComputer".
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-computer-management'
    Name        = 'Computer Management'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Computer Management: Device Manager, disks, event logs, services, local users and shared folders in one window.'
    Apply       = { Start-Process 'compmgmt.msc' }
}
