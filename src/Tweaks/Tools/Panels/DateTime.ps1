# Ported from Chris Titus Tech's winutil (MIT), config/feature.json "WPFPanelTimedate" (the classic dialog;
# system-open-date-time is Settings' page).
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-panel-date-time'
    Name        = 'Date and Time'
    Section     = 'Tools'
    Category    = 'Panels'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens the classic Date and Time dialog: the time zone, extra clocks, Internet time.'
    Apply       = { Start-Process 'timedate.cpl' }
}
