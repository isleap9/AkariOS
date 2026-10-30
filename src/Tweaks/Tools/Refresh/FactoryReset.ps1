# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "Factory Reset" (it only opens the page).
# Action: it opens Windows' own recovery page; Windows asks before it resets anything.
@{
    Id          = 'tools-factory-reset'
    Name        = 'Factory reset'
    Section     = 'Tools'
    Category    = 'Refresh'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Settings > System > Recovery, where "Reset this PC" reinstalls Windows.'
    Apply       = { Start-Process 'ms-settings:recovery' }
}
