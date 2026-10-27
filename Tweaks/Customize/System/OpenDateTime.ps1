# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup "Date Language Region Time" (it only opens the page).
# Action: it opens a page and changes nothing, so there is nothing to revert.
@{
    Id          = 'system-open-date-time'
    Name        = 'Date, language, region and time'
    Section     = 'Customize'
    Category    = 'System'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens Settings > Time & language > Date & time.'
    Apply       = { Start-Process 'ms-settings:dateandtime' }
}
