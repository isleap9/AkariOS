# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Scaling" (it only opens the page).
# Action: it opens a page and changes nothing, so there is nothing to revert.
@{
    Id          = 'system-open-display-scaling'
    Name        = 'Advanced display scaling'
    Section     = 'Customize'
    Category    = 'System'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens Settings > Display > Advanced display (custom scaling, refresh rate).'
    Apply       = { Start-Process 'ms-settings:display-advanced' }
}
