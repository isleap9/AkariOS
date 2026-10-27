# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Resolution Refresh Rate" (it only opens the page).
# Action: it opens a page and changes nothing, so there is nothing to revert.
@{
    Id          = 'graphics-open-display'
    Name        = 'Resolution and refresh rate'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens Settings > Display: run your monitor at its native resolution and highest refresh rate.'
    Apply       = { Start-Process 'ms-settings:display' }
}
