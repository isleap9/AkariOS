# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup "Startup Apps" (Settings; it only opens the page).
# Action: it opens a page and changes nothing, so there is nothing to revert.
@{
    Id          = 'performance-open-startup-apps'
    Name        = 'Startup apps (Settings)'
    Section     = 'Optimize'
    Category    = 'Performance'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens Settings > Apps > Startup: turn off the apps you don''t need at sign-in.'
    Apply       = { Start-Process 'ms-settings:startupapps' }
}
